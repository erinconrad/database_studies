function [session_id,pt] = build_sessions(id,start_time,end_time,gap,T)

%% Get unique patients
neegs = length(id);

session_id = nan(neegs,1);
big_count = 0;

% Loop over eegs
for ie = 1:neegs
    
    % see if session id exists, skip it if it does
    if ~isnan(session_id(ie)), continue; end
    
    % get current pt
    curr_pt = id(ie);
    
    % find matching patients
    same_pt_eegs = find(id==curr_pt);
    
    % sort by start time
    [same_pt_start,I] = sort(start_time(same_pt_eegs));
    same_pt_eegs = same_pt_eegs(I);
    
    % loop over these eegs
    big_count = big_count + 1;
    %assert(same_pt_eegs(1)==ie)
    session_id(same_pt_eegs(1)) = big_count;
    
    for je = 2:length(same_pt_eegs)
        if same_pt_start(je) - same_pt_start((je-1)) < gap
            session_id(same_pt_eegs(je)) = big_count;
        else
            big_count = big_count + 1;
            session_id(same_pt_eegs(je)) = big_count;
            
          
        end
        
    end
    
    
end

%% epileptiform discharges or seizures
discharges = [5 6 7];
slowing = [2 3 4];
seizures = [8 9];
is_sz = cellfun(@(x) text_contains_num(x,seizures), T.interpretation_findings);
is_spike = cellfun(@(x) text_contains_num(x,discharges), T.interpretation_findings);

%% Now get all sessions per pt and all eegs per session
unique_pts = unique(id);
npts = length(unique_pts);
for ip = 1:npts
    
    curr_id = unique_pts(ip);
    
    % find all eegs
    curr_pt_eegs = find(id == curr_id);
    
    % find sessions
    sessions = session_id(curr_pt_eegs);
    
    unique_sessions = unique(sessions);
    nsessions = length(unique_sessions);
    
    pt(ip).id = curr_id;
    
    for is = 1:nsessions
        
        curr_session = unique_sessions(is);
        
        % get session id
        curr_session_eegs = find(session_id == curr_session);
        
        % order these by start time
        [~,I] = sort(start_time(curr_session_eegs));
        curr_session_eegs = curr_session_eegs(I);
        
        
        
        pt(ip).session(is).id = curr_session;
        pt(ip).session(is).eegs = curr_session_eegs;
        pt(ip).session(is).times = [start_time(curr_session_eegs),end_time(curr_session_eegs)];
        pt(ip).session(is).full_duration = sum(end_time(curr_session_eegs)-start_time(curr_session_eegs));
        pt(ip).session(is).durations = [end_time(curr_session_eegs)-start_time(curr_session_eegs)];
        pt(ip).session(is).pts = id(curr_session_eegs);
        pt(ip).session(is).sessions = session_id(curr_session_eegs);
        pt(ip).session(is).is_ltm = pt(ip).session(is).full_duration > 3600*12;
        pt(ip).session(is).routine_start = pt(ip).session(is).durations(1) < 3600;
        pt(ip).session(is).start_duration = pt(ip).session(is).durations(1);
        
        assert(length(unique(pt(ip).session(is).sessions)) == 1)
        assert(length(unique(pt(ip).session(is).pts)) == 1)
        
        % get various clinical variables
        pt(ip).session(is).is_spike = is_spike(curr_session_eegs);
        pt(ip).session(is).is_sz = is_sz(curr_session_eegs);
        
        % find first sz
        pt(ip).session(is).first_sz = find_first_x(is_sz(curr_session_eegs));
        
        % any sz
        pt(ip).session(is).any_sz = any(is_sz(curr_session_eegs));
        
        % find first spike
        pt(ip).session(is).first_spike = find_first_x(is_spike(curr_session_eegs));
        
    end
    
end

end