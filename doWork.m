clc
clear
addpath(genpath('.'));
addpath('../../mexopencv/mexopencv');

input='..\data\10_panda\';
D = dir(fullfile(input,'*.jpg'));
file_list={D.name};

%%for LSH
nbin = 32;            %number of bins
alpha = 0.5;         %parameter of LSH, [0.0,1.0]
k = 0.005;              %parameter of illumination invariant features

%% control parameter
record_vid = false;
image_scale = 1;
max_train_sz = 200;
pixel_step = 4;
use_color = true;
search_roi = 3; % the ratio of the search radius to the longest edge of bbox
init_step = 20;
start_frame = 1;


visualize_medscore_size = 200;


%% counters
sample_count = 0;
initialized = true;


%%%%%%%%%%%%%%%%%%%%%%%
global tracker;

tracker=particleTracker();
svm_tracker = svmTracker();
sam_num = 9;
thr = 1/sam_num:1/sam_num:1-1/sam_num;
fd = length(thr);
patterns={};
costs={};
medscore=zeros(1,visualize_medscore_size);

% config
global config
global finish %flag for determination
config.verbose = false;
config.image_scale = image_scale;
config.use_color = use_color;
config.search_roi = search_roi;
config.hist_decay = 0.1;
config.hist_nbin = 32;
config.IIF_k = 0.005;
config.fd = fd;
config.thr =thr;
config.pixel_step = pixel_step;
config.padding = 20;%for object out of border
config.use_raw_feat = false;%do not explode the feature
config.thresh_p = 0.1;
config.thresh_n = 0.5;



if record_vid
    vid = avifile('./output/output.avi');
end


figure(1); set(1,'KeyPressFcn', @handleKey); % open figure for display of results
figure(2); set(2,'KeyPressFcn', @handleKey); 
figure(3); set(3,'KeyPressFcn', @handleKey); 
finish = 0; 

for frame_id=start_frame:numel(file_list)
    disp('**********************')
    if finish == 1
        break;
    end
    
    %% read a frame
    I_orig=imread(fullfile(input,file_list{frame_id})); 
    
    [I_orig]= getFrame2Compute(I_orig);
    
    %% intialize a bbox
    if frame_id==start_frame
        figure(1)
        imshow(I_orig);
        % crop to get the initial window
        [InitPatch rect]=imcrop(I_orig); rect = round(rect);%
%         rect = [170    66    56    65];
        tracker.output = rect;
    end
    
    %% compute ROI
    roi = rsz_rt(tracker.output,size(I_orig),config.search_roi);
    tracker.roi = roi;
    
    %% crop frame
    I_crop = I_orig(tracker.roi(2):tracker.roi(4),tracker.roi(1):tracker.roi(3),:);
    %% compute feature images
tic
    alpha = exp(-sqrt(2)/(config.hist_decay*min(tracker.output(3:4))));
    [BC F] = getFeatureRep(I_crop,alpha,config.hist_nbin,config.IIF_k,config.pixel_step);
toc
   
   
   %% tracking part
%    tic
   if frame_id==start_frame
       initTracker(rect,BC,pixel_step,use_color);
       train_mask = (tracker.costs<config.thresh_p) | (tracker.costs>config.thresh_n);
       label = tracker.costs(train_mask,1)<config.thresh_p;
%        ft_w = ones(1,size(tracker.template,1)*size(tracker.template,2)*size(tracker.template,3));
tic
       svm_tracker = initSvmTracker(svm_tracker,tracker.patterns_dt(train_mask,:), label);
toc
       fig=figure(1);
       imshow(I_orig);
       rectangle('position',tracker.output,'LineWidth',2,'EdgeColor','b')
   else
       % testing
       
       figure(1)
       imshow(I_orig);       
       roi_reg = tracker.roi; roi_reg(3:4) = roi(3:4)-roi(1:2);
       rectangle('position',roi_reg,'LineWidth',1,'EdgeColor','r');
       
       %correct tracker and label
       if (~initialized)
tic
           updateTracker(BC);
toc
           rectangle('position',tracker.output,'LineWidth',2,'EdgeColor','b')
           if frame_id >0 & tracker.med_score>0.0
               initialized = true;
           end
       else %adhoc step for initialization finished
tic
           updateTrackerLite(BC);
toc
           [svm_result_idx svm_tracker.confidence]= svmTrackerDo(svm_tracker,tracker.patterns_dt);
           rectangle('position',tracker.output,'LineWidth',2,'EdgeColor','b')
           if svm_tracker.confidence > -1
               text(0,0,num2str(svm_tracker.confidence));
               rectangle('position',tracker.state_dt(svm_result_idx,:),'LineWidth',2,'EdgeColor','g')
           else
               text(0,0,num2str(svm_tracker.confidence));
               rectangle('position',tracker.state_dt(svm_result_idx,:),'LineWidth',2,'EdgeColor','r')
           end
           if svm_tracker.confidence > -1
               tracker = correctTracker(tracker,BC,svm_result_idx);
           end
       end
       train_mask = (tracker.costs<config.thresh_p) | (tracker.costs>config.thresh_n);
%        if svm_tracker.confidence < 0.7
%            train_mask = train_mask & (tracker.costs>config.thresh_n);
%        end
       label = tracker.costs(train_mask,1)<config.thresh_p;
      %% visualize traing sample
%        pos_train = tracker.state_dt(train_mask,:);
%        for k = 1:size(label,1)
%            px = pos_train(k,1)+0.5*pos_train(k,3);
%            py = pos_train(k,2)+0.5*pos_train(k,4);
%            if label(k)>0
%                rectangle('position',[px,py,1,1],'LineWidth',1,'EdgeColor','g')
%            else
%                rectangle('position',[px,py,1,1],'LineWidth',1,'EdgeColor','r')
%            end
%        end
tic
       if svm_tracker.confidence > -1
           svm_tracker = updateSvmTracker (svm_tracker,tracker.patterns_dt(train_mask,:),label);
       end
toc
   end
%    toc
   %% visulize results
%    figure(1)
%    for i=1:size(tracker.topK,1)
%        rectangle('position',tracker.topK(i,:),'LineWidth',1,'EdgeColor','r')
%    end
   fig=figure(1);
%    rectangle('position',tracker.output,'LineWidth',2,'EdgeColor','b')
   if record_vid
       Fr = getframe(fig);
       vid = addframe(vid,Fr);
   end
   
%    figure(2)
%    if ~use_color
%        subplot(1,3,1)
%        imshow(1-F{1});
%        subplot(1,3,2)
%        imshow(F{2});
%        subplot(1,3,3)
%        imshow(F{3});
%    else
%        subplot(1,5,1)
%        imshow(1-F{1});
%        subplot(1,5,2)
%        imshow(F{2});
%        subplot(1,5,3)
%        imshow(F{3});
%        subplot(1,5,4)
%        imshow(F{4});
%        subplot(1,5,5)
%        imshow(F{5});
%    end
       
   
%    figure(3)
%    imshow(F1)
%    patterns{mod(sample_count,max_train_sz)+1} = tracker.patterns_ft*kron(eye(tracker.feature_num),ones(fd,1)/fd);%[F1,F2,F3...]3d / 5d feature
%    costs{mod(sample_count,max_train_sz)+1} = tracker.costs;
   sample_count = sample_count+1;
%    tracker.ft_w = -1*ones(1,tracker.feature_num);%svm_learn(patterns,costs,tracker.ft_w')';
   if sample_count > visualize_medscore_size
       medscore(1:end-1) = medscore(2:end);
       medscore(end) = tracker.med_score;
%        disp(tracker.med_score);
   else
       medscore(sample_count) = tracker.med_score;
   end
   figure(3)
   subplot(2,3,1)
%    plot(medscore,'-o')
   subplot(2,3,2)
%    imshow(I_orig(round(tracker.output(2):tracker.output(2)+tracker.output(4)-1),...
%        round(tracker.output(1):tracker.output(1)+tracker.output(3)-1),:));
   subplot(2,3,3) % visualize svm weight vector
   svm_w = abs(reshape(svm_tracker.clsf.w,size(tracker.template,1),size(tracker.template,2),[]));
   imagesc(sum(svm_w,3));
   subplot(2,3,4:6)
   plot(sum(reshape(svm_w,size(tracker.template,1)*size(tracker.template,2),[]),1),'go')
   
%    if svm_tracker.solver == 5
%        fig = figure(5);
%        clf(fig);
%        sv_num = size(svm_tracker.pos_sv,1);
%        pos_score_sv = -(svm_tracker.pos_sv*svm_tracker.clsf.w'+svm_tracker.clsf.Bias);
%        for i = 1:sv_num
%            sv = reshape(svm_tracker.pos_sv(i,:),size(tracker.template,1),...
%                size(tracker.template,2),[]);
%            sv = sv(:,:,3);
%            subplot(1,sv_num,i)
%            imshow(sv);
%            text(0,0,num2str(pos_score_sv(i)));
%        end
% %        pause
%    end


%    pause
   
%    plot(-tracker.ft_w,'o');
   
   
%    tic
%    label = (tracker.costs<0.1) - (tracker.costs>0.5);
%    label = label(label~=0);
%    if frame_id > 1
%        [group resp] = svmclassify_my(clsf,tracker.patterns_dt);
% %        confusionmat(label,group)
%        figure(4)
%        plot(resp,tracker.costs,'o');
%    end
%    
%    clsf = svmtrain( tracker.patterns_dt((tracker.costs<0.1) | (tracker.costs>0.5),:),...
%        label,'kernel_function','rbf','rbf_sigma',100,'boxconstraint',1.0,'autoscale','false');
%    toc
   
%    figure(1);hold on
%    rect_supp = tracker.state_dt((tracker.costs<0.1) | (tracker.costs>0.5),:);
%    idx_supp = clsf.SupportVectorIndices(clsf.Alpha<0);
%    for i = 1:size(idx_supp,1)
%        rectangle('position',rect_supp(idx_supp(i),:),'LineWidth',2,'EdgeColor','r')
%    end
   
%    keyboard
%    subplot(1,3,2)
%    [ft_min, ~] = min(tracker.ft_w); % weights should be negative
%    ft_w_exp = kron(tracker.ft_w==ft_min,ones(1,size(BC,3)/tracker.feature_num));
%    tp = tracker.template(:,:,ft_w_exp>0);
%    diff = (tracker.patterns_dt(:,size(tp(:),1)+1 : size(tp(:),1)*2)-repmat(tp(:)',[size(tracker.patterns_dt,1),1]));
%    plot(mean(diff.^2,2),tracker.costs,'g*');
%    if frame_id > 1
%        subplot(1,3,3)
%        plot(dot(diff*tracker.inv_cov,diff,2)/size(diff,2),tracker.costs,'rO');
%    end
   
   
   
%    tracker.sp_w = 0.95*tracker.sp_w + 0.05*ridgereg(tracker.patterns_sp,tracker.costs,500); 
   
%    imshow(imresize(reshape(tracker.sp_w,tracker.rn,[]),rect(4:-1:3))/max(tracker.sp_w));
%    pause
   
   
   %pause(0.5);
   
end
if record_vid
    vid = close(vid);
end