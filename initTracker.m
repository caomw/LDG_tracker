function initTracker(init_rect,I_vf,step,use_color)
global tracker;

tracker.step = step;
tracker.state=kron(ones(size(tracker.state,1),1),init_rect);
tracker.state(:,1:2) = tracker.state(:,1:2)+(rand(size(tracker.state,1),2)-0.5).*(tracker.radius*2*max(tracker.state(1,3:4)));
tracker.output=init_rect;
tracker.topK=kron(ones(10,1),init_rect);
tracker.shrange = [init_rect(1)-init_rect(3),init_rect(2)-init_rect(4),...
    init_rect(1)+2*init_rect(3), init_rect(2)+2*init_rect(4)];
% template_vf=I_vf(round(init_rect(2):init_rect(2)+init_rect(4)),round(init_rect(1):init_rect(1)+init_rect(3)),:);
% template_vf=reshape(template_vf,size(template_vf,1)*size(template_vf,2),size(template_vf,3));
% tracker.template=cov(template_vf);
init_rect_roi = init_rect;
init_rect_roi(1:2) = init_rect(1:2) - tracker.roi(1:2)+1;
tracker.template = I_vf (round(init_rect_roi(2):tracker.step:init_rect_roi(2)+init_rect_roi(4)),...
    round(init_rect_roi(1):tracker.step:init_rect_roi(1)+init_rect_roi(3)),:);
if use_color
    tracker.feature_num = 5;
%     tracker.ft_w = -1*ones(1,tracker.feature_num);
else
    tracker.feature_num = 3;
%     tracker.ft_w = -1*ones(1,tracker.feature_num);
end
% spatial weight size
tracker.r_step = ceil(size(tracker.template,1)/20);
tracker.c_step = ceil(size(tracker.template,2)/20);
tracker.rn = floor((size(tracker.template,1)-1)/tracker.step)+1;
tracker.cn = floor((size(tracker.template,2)-1)/tracker.step)+1;
% tracker.sp_w = ones(tracker.rn*tracker.cn,1);
%tracker.wt = fspecial('gaussian',[size(tracker.template,1),size(tracker.template,2)],0.5*size(tracker.template,2));

% store random projection matrix
% tracker.hash_mtx = getRandPrjMtx(size(tracker.template,1)*size(tracker.template,2)*size(tracker.template,3),50);
% tracker.hash_mtx([1:15,31:45],:) = 0;
% tracker.pos_hist = zeros(1,2^5);
% tracker.neg_hist = zeros(1,2^5);
% tracker.output_code = 1;

%% for collecting initial training data
updateTracker(I_vf);
tracker.output=init_rect;
% tracker.patterns_ft = tracker_tmp.patterns_ft;
% tracker.patterns_dt = tracker_tmp.patterns_dt;
% tracker.state_dt = tracker_tmp.state_dt;
% tracker.costs = tracker_tmp.costs;
% tracker.med_score = tracker_tmp.med_score;



