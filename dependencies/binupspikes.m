function [binned_spikes, spikes_wrt_event, firstspike_wrt_event] = binupspikes(spikes, refevents,s_b4, s_post)
    binned_spikes = cell(numel(refevents),1);    
    spikes_wrt_event = cell(numel(refevents),1);
    firstspike_wrt_event = nan(numel(refevents),1);
    for i_ref = 1:numel(refevents)
        spikes_before_event = spikes < refevents(i_ref) + s_post;
        spikes_after_event = spikes > refevents(i_ref)-s_b4;
        binned_spikes{i_ref} = spikes(spikes_before_event & spikes_after_event);
        spikes_wrt_event{i_ref} = binned_spikes{i_ref} - refevents(i_ref);
        
        if ~isempty(spikes_wrt_event{i_ref})
            % get the first spike wrt the event:
            firstspike_idx = find(spikes_wrt_event{i_ref}>0,1,'first');
            if ~isempty(firstspike_idx)
                firstspike_wrt_event(i_ref) = spikes_wrt_event{i_ref}(firstspike_idx);
            end

            % assert conditions for binning
            assert(binned_spikes{i_ref}(1) > refevents(i_ref)-s_b4 && binned_spikes{i_ref}(end) < refevents(i_ref)+s_post);
            assert(spikes_wrt_event{i_ref}(1) > 0-s_b4 && spikes_wrt_event{i_ref}(end) < s_post);
        end
    end
end
        