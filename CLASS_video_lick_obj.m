classdef CLASS_video_lick_obj < handle
    % 
    %   Created     2/5/24 ahamilos
    %   Modified    3/2/24 ahamilos | VERSION CODE: ['CLASS_video_lick_obj v1.3 Modified 3-2-24 13:00 | obj created: ' datestr(now)];
    % 
    % 	----------------------
    % 	Dependencies from harvardschoolofmouse libraries:
    % 		correctPathOS
    % 		makeStandardFigure
    %       prettyHxg
    %
    %	Developed in Matlab 2023a on MacOS
    %       Requires Image Processing Toolbox
    % 
    % 	----------------------
    %	File types:
    %		Videos: should be stored in a folder -- during data collection, flycap/spinnaker automatically gives 
    %					video-number in name of each file so that they are in order
    %		CED (spike2 export): .mat file with spike2 export of session's .smr file, using HSOM channel naming practices and sampling rates
    % 
    % 
    %   VERSION CODE HISTORY
    % 
    properties
        iv
        ROIs
        video
        CED
        analysis
        currentVid
        videomap
    end



    %-------------------------------------------------------
    %       Methods: Initialization
    %-------------------------------------------------------
    methods
        function obj = CLASS_video_lick_obj(useCueROI, doIRtrigseparately)
            if nargin < 3, doIRtrigseparately = true;end
        	if nargin < 2, useCueROI = false;end
            % 
            disp('-----------------------------------')
            disp(' => Collecting data from file...')
            % get initial variables
            obj.getIV();
            % get files for analysis
            obj.getData();
            obj.indexFramesAcrossVideos;
            obj.save(true);
            disp(' 		*** can safely kill here or pause if you''ve made a mistake.')

			if useCueROI
				disp(' => Get all ROIs for cue and lick')
	            obj.setAllROIs('cue');
	            obj.detectMultiEvents('cue');
	            obj.save(false);
	            disp(' 		*** can safely kill here or pause if you''ve made a mistake.')
	            
	            disp(' => Detecting trial-start events...')
	            LineROI = obj.setThreshold('cue');
	            disp(' => Detecting lick events...')
            	LineROI = obj.setThreshold('lick');
            	disp(' => Initial alignment of video to CED...')
            	obj.iv.CUEtriggered = true;
        	else
	            disp(' => Get all ROIs for lampOff and lick')
	            obj.setAllROIs('lampoff');
	            obj.detectMultiEvents('lampoff');
	            obj.save(false);
	            disp(' 		*** can safely kill here or pause if you''ve made a mistake.')
	            
	            disp(' => Detecting trial-start events...')
	            LineROI = obj.setThreshold('lampOFF');
	            disp(' => Detecting lick events...')
            	LineROI = obj.setThreshold('lick');
            	disp(' => Initial alignment of video to CED...')
            end
            if numel(obj.CED.lampOff_s) > numel(obj.CED.cue_s)
                obj.CED.lampOff_s(end) = [];
                obj.CED.lampOn_s(end) = [];
            end
            obj.getVideoTrialStartFrames(false); % set to true if you must use the cue but need to gather IRtrig...this doesnt really work so probably will get rid of this later
            obj.alignCED_to_video;
            disp(' => Collecting user corrections to trial-start data...')
            obj.UIcleanUpTrialStarts(true);
            obj.save(false);
            
            disp(' => Gathering lick data for comparisons...')
            obj.getVideoLicks;
            obj.gatherLicks;
            obj.plotLicksByTime;
            obj.save(false);
            disp(' => All your data has been collected and saved. ')
            disp(' => Next, you should run: ')
            disp(' ')
            disp('          obj.UIexamineLicking(0.15, true)')
            disp(' ')
            disp('^^(copy this and run it! You will curate licks)')
            disp('--------------------------- \finis')
        end
        function save(obj, Revise)
            if nargin<2, Revise = false;end
        	retdir = pwd;
        	cd(obj.iv.savepath)
        	if Revise
				timestamp_now = datestr(now,'mm_dd_yy__HH_MM_AM');
				savefilename = [obj.iv.name '_videoQCobj'];
				obj.iv.savefilename = savefilename;
			else
				savefilename = obj.iv.savefilename;
			end

			save([savefilename, '.mat'], 'obj', '-v7.3');
			disp([' 		=> ...saved progress to file: ' savefilename])
			disp(' ')
			cd(retdir)
		end
        function getData(obj)
            disp('select video file folder');
            videofolder = uigetdir('select video file folder');
            disp('select CED .mat file');
            [file, path] = uigetfile('.mat', 'select CED .mat file');
            CEDfile = correctPathOS([path, file]);
            obj.iv.savepath = path;
            name = strsplit(videofolder, '/');
		    name = cellfun(@(x) strsplit(x, '\'), name, 'uniformoutput', 0);
		    if iscell(name)
		        name = name{end};
		    else
		        name = name(end);
		    end
		    if iscell(name)
		        name = cell2mat(name);
		    end
		    obj.iv.name = name;
            obj.iv.videofolder = videofolder;
            obj.iv.CEDfile = CEDfile;
            obj.importCEDdata;	

            % get videoidx
            videofolder = obj.iv.videofolder;
    		retdir = pwd;
    		cd(videofolder)
			videoidx = dir;
			videoidx = videoidx(3:end);
            if contains([videoidx.name], '.DS_Store')
                videoidx = videoidx(2:end,:);
            end
			obj.iv.videoidx = videoidx;
			cd(retdir)	
        end
        function importCEDdata(obj)
        	load(obj.iv.CEDfile);
            strsplit(obj.iv.CEDfile, '\');
            n = strsplit(obj.iv.CEDfile, '\');
            if numel(n) == 1
                n = strsplit(obj.iv.CEDfile, '/');
            end
            n = n{end};
            n = strsplit(n, '.mat');
            n = n{1};
            obj.CED.IRtrig_s = eval([n '_IRtrig.times;']);
            obj.CED.CamO_s = eval([n '_CamO.times;']);
            obj.CED.lampOff_s = eval([n '_Lamp_OFF.times;']);
            obj.CED.lampOn_s = eval([n '_LampON.times;']);
            obj.CED.cue_s = eval([n '_Start_Cu.times;']);
            obj.CED.lick_s = eval([n '_Lick.times;']);
            try
                obj.CED.juice_V = eval([n '_Juice.values;']);
            end
            obj.CED.juice_s = eval([n '_Juice.times;']);
        end
        function getIV(obj)
        	obj.iv.versionCode = 'CLASS_video_lick_obj v1.1 Modified 2-8-24 20:00';
        	obj.iv.zoom = 2.5;
            obj.iv.trialsAligned = false;
    	end
    	function progressBar(obj, iter, total, nested, cutter)
			if nargin < 5
				cutter = 1000;
			end
			if nargin < 4
				nested = false;
			end
			if nested
				prefix = '		';
			else
				prefix = '';
			end
			if rem(iter,total*.1) == 0 || rem(iter, cutter) == 0
				done = {'=', '=', '=', '=', '=', '=', '=', '=', '=', '='};
				incomplete = {'-', '-', '-', '-', '-', '-', '-', '-', '-', '-'};
				ndone = round(iter/total * 10);
				nincomp = round((1 - iter/total) * 10);
				disp([prefix '	*' horzcat(done{1:ndone}) horzcat(incomplete{1:nincomp}) '	(' num2str(iter) '/' num2str(total) ') ' datestr(now)]);
			end
		end
    	function getVideoHandle(obj, fileNo)
    		retdir = pwd;
    		cd(obj.iv.videofolder)
    		videoidx = obj.iv.videoidx;
            if contains([videoidx.name], '.DS_Store')
                videoidx = videoidx(2:end,:);
            end
    		fileName = videoidx(fileNo).name;   
		    filePath = [pwd,'/',fileName];
		    vid = VideoReader(fileName);
		    frameRate = vid.FrameRate;
		    Height = vid.Height;
		    Width = vid.Width;
		    NumFrames = vid.NumFrames;
		    AspectRatio = Height/Width;

		    obj.iv.Height = Height;
		    obj.iv.Width = Width;
		    obj.iv.AspectRatio = AspectRatio;
		    obj.iv.frameRate = AspectRatio;

            obj.currentVid.vid = vid;
            obj.currentVid.fileNo = fileNo;
            obj.currentVid.Height = Height;
            obj.currentVid.NumFrames = NumFrames;
            obj.currentVid.Width = Width;
            obj.currentVid.AspectRatio = AspectRatio;
            obj.currentVid.frameRate = frameRate;
            obj.currentVid.fileName = fileName;
            obj.currentVid.filePath = filePath;
		    cd(retdir)	
		end
		function indexFramesAcrossVideos(obj)
			obj.videomap = [];
            obj.videomap.fileNo = [];
			obj.videomap.frameNo_by_video = [];
			obj.videomap.frameNo = [];
            currend = 0;
			for ii = 1:numel(obj.iv.videoidx)
				obj.getVideoHandle(ii);
				nframes = obj.currentVid.NumFrames;
                [obj.videomap(currend+1:currend+nframes).fileNo] = deal(ii);
                t = num2cell(1:nframes);
				[obj.videomap(currend+1:currend+nframes).frameNo_by_video] = t{:};
				t = num2cell(currend+1:currend+nframes);
                [obj.videomap(currend+1:currend+nframes).frameNo] = t{:};
                currend = obj.videomap(end).frameNo;
            end
		end
		function [f,ax] = makeVideoFrame(obj, ax)
			zoom = obj.iv.zoom;
			Width = obj.currentVid.Width;
			Height = obj.currentVid.Height;
            fileNo = obj.currentVid.fileNo;
            if nargin < 2
				[f,ax] = makeStandardFigure();
                set(f, 'units', 'pixels');
		        set(f, 'position', [1600, 0, zoom*Width+125, zoom*Height+125])
                set(f, 'units', 'normalized')
                fpos = get(f, 'position');
                fpos(1) = 0.7;
                set(f, 'position', fpos)
                set(f, 'name', [obj.iv.name, ' | video #' num2str(fileNo)])
                set(f, 'userdata', [obj.iv.name, ' | video #' num2str(fileNo)])
                set(ax, 'units', 'pixels')
		        set(ax, 'position', [75, 75, zoom*Width, zoom*Height])
            end
		    set(ax,'YDir','reverse')
		end
		function frame = getFrame(obj, i_timepoint)
            vid = obj.currentVid.vid;
			frame = read(vid, i_timepoint);
            obj.currentVid.frame = frame;
            obj.currentVid.i_timepoint = i_timepoint;
		end
		function [roi, pos, x_ix, y_ix] = getROI(obj, ax, frame, i_timepoint)
			Width = obj.currentVid.Width;
			Height = obj.currentVid.Height;
			frameRate = obj.currentVid.frameRate;
		
			xlim(ax,[0, Width])
            ylim(ax,[0, Height])
            hImage = image(frame,"Parent",ax);
            title(ax,['frame #: ' num2str(i_timepoint) ' | time: ' num2str((i_timepoint-1)*frameRate)])
            disp('Press ESC if the mouse is grooming or to advance frame (if want to see Houselamp turn off). We can open a different frame')
            roi = [];
            while isempty(roi)
                roi = drawrectangle(ax);
                if isempty(roi.Position)
                    vid = obj.currentVid.vid;
                    i_timepoint = i_timepoint+10;
		            frame = read(vid, i_timepoint);
                    hImage = image(frame,"Parent",ax);
                    title(ax,['frame #: ' num2str(i_timepoint) ' | time: ' num2str((i_timepoint-1)*frameRate)])
                    roi = [];
                end
            end
            pos = roi.Position;
            x_ix = round(pos(2):pos(2)+pos(4));
            y_ix = round(pos(1):pos(1)+pos(3));
            
		end
    	function detectLicks(obj)
    		Style = 'LICK';
    		[Pixels, mean_pixels] = obj.detectROI(Style);
			obj.video.lick.mean_pixels_by_video = mean_pixels;
			% concatenate the mean_pixels...
			obj.video.lick.mean_pixels = cell2mat(mean_pixels);			
		end
		function detectCue(obj)
    		Style = 'CUE';
    		[Pixels, mean_pixels] = obj.detectROI(Style);
			obj.video.cue.mean_pixels_by_video = mean_pixels;
			% concatenate the mean_pixels...
			obj.video.cue.mean_pixels = cell2mat(mean_pixels);			
		end
		function detectMouse(obj)
    		Style = 'MOUSE';
    		[Pixels, mean_pixels] = obj.detectROI(Style);
			obj.video.mouse.mean_pixels_by_video = mean_pixels;
			% concatenate the mean_pixels...
			obj.video.mouse.mean_pixels = cell2mat(mean_pixels);			
		end
		function detectLampOff(obj, useStoredROI)
    		Style = 'LAMPOFF';
    		[Pixels, mean_pixels] = obj.detectROI(Style);
			obj.video.lampOFF.mean_pixels_by_video = mean_pixels;
			% concatenate the mean_pixels...
			obj.video.lampOFF.mean_pixels = cell2mat(mean_pixels);			
		end
		function detectMultiEvents(obj, Mode)
			% 
			% 	Using stored ROIs, process the whole video only once
			% 
			videofolder = obj.iv.videofolder;
    		retdir = pwd;
    		cd(videofolder)
			videoidx = dir;
			videoidx = videoidx(3:end);
            if contains([videoidx.name], '.DS_Store')
                videoidx = videoidx(2:end,:);
            end
			obj.iv.videoidx = videoidx;
			obj.ROI_detector_multi(videoidx, Mode);
			cd(retdir)		
		end
		function [Pixels, mean_pixels] = detectROI(obj, Style)
			videofolder = obj.iv.videofolder;
    		retdir = pwd;
    		cd(videofolder)
			videoidx = dir;
			videoidx = videoidx(3:end);
            if contains([videoidx.name], '.DS_Store')
                videoidx = videoidx(2:end,:);
            end
			obj.iv.videoidx = videoidx;
			[Pixels, mean_pixels] = obj.ROI_detector(videoidx, Style);
			cd(retdir)
		end
		function [Pixels, mean_pixels] = ROI_detector(obj, videoidx, Style)
			ROIfield = obj.getROIfieldnameROI(Style);
			% prepare container for ROI pixel intensity for each video
			mean_pixels = cell(numel(videoidx),1); 
			% iterate videos...
			disp(['Select the ' Style ' ROI'])
			for fileNo = 1:numel(videoidx)
				obj.progressBar(fileNo, numel(videoidx), false, 1)
			    % open the relevant video
				obj.getVideoHandle(fileNo);			    
			    %% get the ROI and process all the videos
			    mean_pixels{fileNo} = nan(5000,1);
			    % for each timepoint, plot the video frame and then overlay the keypoints
			    for i_timepoint = 1:obj.currentVid.NumFrames
			        frame = obj.getFrame(i_timepoint);
			        if fileNo == 1 && i_timepoint == 1
			            [f,ax] = obj.makeVideoFrame;
			            [roi, pos, x_ix, y_ix] = obj.getROI(ax, frame, i_timepoint);
                        ROIfield.pos = pos;
                        ROIfield.x_ix = x_ix;
                        ROIfield.y_ix = y_ix;
			        end
			        Pixels = frame(ROIfield.x_ix, ROIfield.y_ix);
			        mean_pixels{fileNo}(i_timepoint) = mean(mean(Pixels));
			    end
			end
			obj.updateROIfieldROI(Style, ROIfield);
			disp('-\ Finis')
		end
		function ROI_detector_multi(obj, videoidx, Mode)
			if nargin < 2, Mode = 'lampOFF';end
			% prepare container for ROI pixel intensity for each video
			if strcmpi(Mode, 'lampOFF')
				obj.video.lampOFF.mean_pixels_by_video = cell(numel(videoidx),1); 
			elseif strcmpi(Mode, 'cue')
				obj.video.cue.mean_pixels_by_video = cell(numel(videoidx),1); 
			end
			obj.video.lick.mean_pixels_by_video = cell(numel(videoidx),1); 
			obj.video.mouse.mean_pixels_by_video = cell(numel(videoidx),1); 
			% iterate videos...
			disp(['Gathering pixel data for all stored ROIs...'])
			for fileNo = 1:numel(videoidx)
				obj.progressBar(fileNo, numel(videoidx), false, 1)
			    % open the relevant video
				obj.getVideoHandle(fileNo);			    
			    %% get the ROI and process all the videos
			    if strcmpi(Mode, 'lampOFF')
				    obj.video.lampOFF.mean_pixels_by_video{fileNo} = nan(2,1);
			    elseif strcmpi(Mode, 'cue')
			    	obj.video.cue.mean_pixels_by_video{fileNo} = nan(2,1);
		    	end
			    obj.video.lick.mean_pixels_by_video{fileNo} = nan(2,1);
			    obj.video.mouse.mean_pixels_by_video{fileNo} = nan(2,1);
			    % for each timepoint, plot the video frame and then overlay the keypoints
			    for i_timepoint = 1:obj.currentVid.NumFrames
			    	if strcmpi(Mode, 'lampOFF')
				        frame = obj.getFrame(i_timepoint);
				        Pixels = frame(obj.ROIs.lampOFF.x_ix, obj.ROIs.lampOFF.y_ix);
				        obj.video.lampOFF.mean_pixels_by_video{fileNo}(i_timepoint) = mean(mean(Pixels));
			        elseif strcmpi(Mode, 'cue')
			        	frame = obj.getFrame(i_timepoint);
				        Pixels = frame(obj.ROIs.cue.x_ix, obj.ROIs.cue.y_ix);
				        obj.video.cue.mean_pixels_by_video{fileNo}(i_timepoint) = mean(mean(Pixels));
			        end

			        Pixels = frame(obj.ROIs.lick.x_ix, obj.ROIs.lick.y_ix);
			        obj.video.lick.mean_pixels_by_video{fileNo}(i_timepoint) = mean(mean(Pixels));

			        Pixels = frame(obj.ROIs.mouse.x_ix, obj.ROIs.mouse.y_ix);
			        obj.video.mouse.mean_pixels_by_video{fileNo}(i_timepoint) = mean(mean(Pixels));
			    end
			end
			% concatenate the mean_pixels...
			if strcmpi(Mode, 'lampOFF')
				obj.video.lampOFF.mean_pixels = cell2mat(obj.video.lampOFF.mean_pixels_by_video);	
			elseif strcmpi(Mode, 'cue')
				obj.video.cue.mean_pixels = cell2mat(obj.video.cue.mean_pixels_by_video);
			end
			obj.video.lick.mean_pixels = cell2mat(obj.video.lick.mean_pixels_by_video);
			obj.video.mouse.mean_pixels = cell2mat(obj.video.mouse.mean_pixels_by_video);
			disp('-\ Finis')
		end
		function setAllROIs(obj, Mode)
			if nargin<2, Mode='lampoff';end
			obj.getVideoHandle(1);
			[f,ax] = obj.makeVideoFrame;
			if strcmpi(Mode, 'lampOFF')
				% get lamp off first
				disp(' ==> Get the LAMP OFF ROI')
				frame = obj.getFrame(1);
	            [roi_lampOFF, pos, x_ix, y_ix] = obj.getROI(ax, frame, 1);
	            ROIfield.pos = pos;
	            ROIfield.x_ix = x_ix;
	            ROIfield.y_ix = y_ix;
	            obj.updateROIfieldROI('LAMPOFF', ROIfield);
            elseif strcmpi(Mode, 'cue')
            	% get cue first
				disp(' ==> Get the CUE ROI')
				frame = obj.getFrame(1);
	            [roi_cue, pos, x_ix, y_ix] = obj.getROI(ax, frame, 1);
	            ROIfield.pos = pos;
	            ROIfield.x_ix = x_ix;
	            ROIfield.y_ix = y_ix;
	            obj.updateROIfieldROI('CUE', ROIfield);
            end
            disp(' ==> Get the LICK ROI')
            [roi_lampOFF, pos, x_ix, y_ix] = obj.getROI(ax, 1, 1);
            ROIfield.pos = pos;
            ROIfield.x_ix = x_ix;
            ROIfield.y_ix = y_ix;
            obj.updateROIfieldROI('LICK', ROIfield);

            disp(' ==> Get the MOUSE ROI')
            [roi_mouse, pos, x_ix, y_ix] = obj.getROI(ax, 1, 1);
            ROIfield.pos = pos;
            ROIfield.x_ix = x_ix;
            ROIfield.y_ix = y_ix;
            obj.updateROIfieldROI('MOUSE', ROIfield);

		end
		function ROIfield = getROIfieldnameVideo(obj, Style)
			if nargin < 2, Style = 'LICK';end
            if strcmpi(Style, 'lick')
                ROIfield = obj.video.lick;
                disp('using Lick zone ROI')
            elseif strcmpi(Style, 'cue')
                ROIfield = obj.video.cue;
                disp('using Cue zone ROI')
            elseif strcmpi(Style, 'LAMPOFF')
                ROIfield = obj.video.lampOFF;
                disp('using lampOFF zone ROI')
            elseif strcmpi(Style, 'MOUSE')
                ROIfield = obj.video.mouse;
                disp('using mouse zone ROI')
            elseif strcmpi(Style, 'UI')
                ROIfield = obj.video.userROI;
                disp('using userROI zone ROI')
            else
                error('not implemented')
            end
		end
		function updateROIfieldVideo(obj, Style, ROIfield)
			if nargin < 2, Style = 'LICK';end
            if strcmpi(Style, 'lick')
                obj.video.lick = ROIfield;
            elseif strcmpi(Style, 'cue')
                obj.video.cue = ROIfield;
            elseif strcmpi(Style, 'LAMPOFF')
                obj.video.lampOFF = ROIfield;
            elseif strcmpi(Style, 'MOUSE')
                obj.video.mouse = ROIfield;
            elseif strcmpi(Style, 'UI')
                obj.video.userROI = ROIfield;
            else
                error('not implemented')
            end
		end
		function ROIfield = getROIfieldnameROI(obj, Style)
			if nargin < 2, Style = 'LICK';end
            if strcmpi(Style, 'lick')
            	if ~isfield(obj.ROIs, 'lick'), obj.ROIs.lick=[];end
                ROIfield = obj.ROIs.lick;
                disp('using Lick zone ROI')
            elseif strcmpi(Style, 'cue')
            	if ~isfield(obj.ROIs, 'cue'), obj.ROIs.cue=[];end
                ROIfield = obj.ROIs.cue;
                disp('using Cue zone ROI')
            elseif strcmpi(Style, 'LAMPOFF')
            	if ~isfield(obj.ROIs, 'lampOFF'), obj.ROIs.lampOFF=[];end
                ROIfield = obj.ROIs.lampOFF;
                disp('using lampOFF zone ROI')
            elseif strcmpi(Style, 'MOUSE')
            	if ~isfield(obj.ROIs, 'mouse'), obj.ROIs.mouse=[];end
                ROIfield = obj.ROIs.mouse;
                disp('using MOUSE zone ROI')
            elseif strcmpi(Style, 'UI')
            	warning('no Style specified. Storing ROI data in obj.ROIs.userROI (overwriting if had before)')
            	if ~isfield(obj.ROIs, 'userROI'), obj.ROIs.userROI = [];end
                ROIfield = obj.ROIs.userROI;
                disp('using userROI zone ROI')
            else
                error('not implemented')
            end
		end
		function updateROIfieldROI(obj, Style, ROIfield)
			if nargin < 2, Style = 'LICK';end
            if strcmpi(Style, 'lick')
                obj.ROIs.lick = ROIfield;
            elseif strcmpi(Style, 'cue')
                obj.ROIs.cue = ROIfield;
            elseif strcmpi(Style, 'LAMPOFF')
                obj.ROIs.lampOFF = ROIfield;
            elseif strcmpi(Style, 'MOUSE')
                obj.ROIs.mouse = ROIfield;
            elseif strcmpi(Style, 'UI')
                obj.ROIs.userROI = ROIfield;
            else
                error('not implemented')
            end
		end
        function ax = plotMeanPixelsByVideo(obj, fileNo, Style)
        	if nargin < 3, Style = 'LICK';end
        	ROIfield = obj.getROIfieldnameVideo(Style);
			[f,ax] = makeStandardFigure;
		    plot(ax, ROIfield.mean_pixels_by_video{fileNo})
		    ylabel(ax, 'intensity')
		    xlabel(ax, 'frame #')
            title(['Mean ' Style, ' ROI intensity by file, fileno: ' num2str(fileNo)])
		end
        function ax = plotMeanPixels(obj,Style,ax, Limits)

        	if nargin < 3 || isempty(ax), [f,ax] = makeStandardFigure;end
            if nargin < 2, Style = 'LICK';end
        	ROIfield = obj.getROIfieldnameVideo(Style);
			if nargin < 4, Limits = 1:numel(ROIfield.mean_pixels);end
		    plot(ax, Limits,ROIfield.mean_pixels(Limits))
		    ylabel(ax, 'intensity')
		    xlabel(ax, 'frame #')
            title(['Mean ' Style, ' ROI intensity, all ' num2str(numel(ROIfield.mean_pixels_by_video)) ' files'])
		end
		function ax = plot(obj, globalFrameNo, ax)
			if nargin<3, ax = [];end
			%
			%	Check for frameshift first
			%
			globalFrameNoTitle = num2str(globalFrameNo);
			if isfield(obj.iv,'frameshift')
				% get global frame of the CED start on this trial:
				frameshift_trial_start_frames_CED = obj.CED.CamO_trialStart_frames_wrt_IRtrig([obj.iv.frameshift.trialNo]);
				requestframeisshifted = find(globalFrameNo>frameshift_trial_start_frames_CED, 1, 'last');
				if ~isempty(requestframeisshifted)
					totalframesshifted = sum([obj.iv.frameshift(1:requestframeisshifted).n_missed_frames]);
					globalFrameNo = globalFrameNo - totalframesshifted;
					globalFrameNoTitle = [globalFrameNoTitle ' - ' num2str(totalframesshifted)];
				end
			end
			% this version will find the right file for you
			fileNo = obj.videomap(globalFrameNo).fileNo;
			i_timepoint = obj.videomap(globalFrameNo).frameNo_by_video;
			time = obj.videomap(globalFrameNo).time_min;
			ax = obj.plotFrame(i_timepoint, fileNo, ax);
			t = ax.Title.String;
			t = [t, ' | globalFrame#: ' globalFrameNoTitle, ' | ' num2str(time) ' min'];
			title(ax, t);
		end
		function ax = plotFrame(obj, i_timepoint, fileNo, ax)
			obj.getVideoHandle(fileNo);
            if nargin < 4 || isempty(ax)
		    	[f,ax] = obj.makeVideoFrame;
	    	else
	    		obj.makeVideoFrame(ax);
            end
	    	Width = obj.currentVid.Width;
	    	Height = obj.currentVid.Height;
	    	frameRate = obj.currentVid.frameRate;
            vid = obj.currentVid.vid;
		    
		    frame = obj.getFrame(i_timepoint);
		    hImage = image(frame,"Parent",ax);
		    title(['frame #: ' num2str(i_timepoint) ' | ' num2str(((i_timepoint-1)/frameRate)/60) 's'])
		    xlim(ax,[0, Width])
		    ylim(ax,[0, Height])
		end
		function plotROI(obj, frame)
			makeStandardFigure, imshow(frame(obj.iv.x_ix, obj.iv.y_ix))
			title('ROI')
		end
		function LineROI = setThreshold(obj, Style, LineROI)
			% 
			% 	Plots meanPixels for the style and allows user to get line ROI where thresh should be
			% 
			if nargin < 2, Style = 'LICK';end
			if nargin < 3
				% if we don't specify the thresholdROI, we should get new
				ax = plotMeanPixels(obj,Style);
				disp('||| -- Draw threshold line')
				LineROI = drawline(ax);
			end
			% if we already have LineROI, adjust it, then feed it 
			% back to the function to update the ROI field
			threshold = mean(LineROI.Position(:,2));
			ROIfield = obj.getROIfieldnameROI(Style);
			ROIfield.threshold = threshold;
			obj.updateROIfieldROI(Style, ROIfield);
        end
        function LineROI = setThresholdHistogram(obj, Style, LineROI)
			% 
			% 	Plots meanPixels for the style and allows user to get line ROI where thresh should be
			% 
			if nargin < 2, Style = 'LICK';end
			if strcmpi(Style, 'lick')
				data = obj.video.lick.mean_pixels;
			elseif strcmpi(Style, 'cue')
				data = obj.video.cue.mean_pixels;
			else
				data = obj.video.lampOFF.mean_pixels;
			end
			if nargin < 3
				% if we don't specify the thresholdROI, we should get new
                [f,ax] = makeStandardFigure;
				h = prettyHxg(ax, data, Style, [1,0,0], [], 500, 'probability');
				disp('||| -- Draw threshold line')
				LineROI = drawline(ax);
			end
			% if we already have LineROI, adjust it, then feed it 
			% back to the function to update the ROI field
			threshold = mean(LineROI.Position(:,1));
			ROIfield = obj.getROIfieldnameROI(Style);
			ROIfield.threshold = threshold;
			obj.updateROIfieldROI(Style, ROIfield);
        end
        
		function getVideoTrialStartFrames(obj,doIRtrigseparately)
			% 
			% 	Once we have set a threshold in LampOff ROI field, we can assign trial start events
			% 
            if nargin<2, doIRtrigseparately=false;end
            if doIRtrigseparately
                % we will only use the first event and assume the
                % rest...for rig 1
                if ~isfield(obj.iv, 'CUEtriggered')
			        threshold = obj.ROIs.lampOFF.threshold;
			        lampOff_logic = obj.video.lampOFF.mean_pixels < threshold;
                    all_transitions = (lampOff_logic(2:end) -  lampOff_logic(1:end-1));
                    down_transitions = all_transitions ==1;
                    neighbor_up_transitions =  [all_transitions(2:end)==-1; 0] | [0; all_transitions(1:end-1)==-1];
			        transitions = find(down_transitions & ~neighbor_up_transitions) + 1;
			        ax = obj.plotMeanPixels('lampOFF');
			        xx = get(ax, 'xlim');
			        plot(ax, [1, xx(2)], [threshold, threshold], 'r--')
			        plot(ax, transitions, threshold.*ones(size(transitions)), 'g.', 'linewidth', 10)
                    obj.video.lampOFF.frames = transitions;
                    obj.video.IRtrig = transitions(1);
                else
                    threshold = obj.ROIs.cue.threshold;
			        lampOff_logic = obj.video.cue.mean_pixels < threshold;
                    all_transitions = (lampOff_logic(2:end) -  lampOff_logic(1:end-1));
                    down_transitions = all_transitions ==1;
                    neighbor_up_transitions =  [all_transitions(2:end)==-1; 0] | [0; all_transitions(1:end-1)==-1];
			        transitions = find(down_transitions & ~neighbor_up_transitions) + 1;
			        ax = obj.plotMeanPixels('cue');
			        xx = get(ax, 'xlim');
                    plot(ax, [1, xx(2)], [threshold, threshold], 'r--')
			        plot(ax, transitions, threshold.*ones(size(transitions)), 'g.', 'linewidth', 10)
                    % this gives us IR trig transition...but we need to
                    % backcalc where cue is...
                    IRtrig = transitions(1);
                    obj.video.cue.frames = [IRtrig+round((obj.CED.cue_s(1)-obj.CED.IRtrig_s)/0.03333);transitions];
                end
            else % we will get each trial start precisely
                if ~isfield(obj.iv, 'CUEtriggered')
			        threshold = obj.ROIs.lampOFF.threshold;
			        lampOff_logic = obj.video.lampOFF.mean_pixels < threshold;
                    all_transitions = (lampOff_logic(2:end) -  lampOff_logic(1:end-1));
                    down_transitions = all_transitions ==1;
                    neighbor_up_transitions =  [all_transitions(2:end)==-1; 0] | [0; all_transitions(1:end-1)==-1];
			        transitions = find(down_transitions & ~neighbor_up_transitions) + 1;
			        ax = obj.plotMeanPixels('lampOFF');
			        xx = get(ax, 'xlim');
			        plot(ax, [1, xx(2)], [threshold, threshold], 'r--')
			        plot(ax, transitions, threshold.*ones(size(transitions)), 'g.', 'linewidth', 10)
                    obj.video.lampOFF.frames = transitions;
                    obj.video.IRtrig = obj.video.lampOFF.frames(1);
                else
                    threshold = obj.ROIs.cue.threshold;
			        lampOff_logic = obj.video.cue.mean_pixels > threshold;
                    all_transitions = (lampOff_logic(2:end) -  lampOff_logic(1:end-1));
                    up_transitions = all_transitions ==1;
                    neighbor_up_transitions =  [all_transitions(2:end)==1; 0] | [0; all_transitions(1:end-1)==1];
			        transitions = find(up_transitions) + 1;
			        ax = obj.plotMeanPixels('cue');
			        xx = get(ax, 'xlim');
			        plot(ax, [1, xx(2)], [threshold, threshold], 'r--')
			        plot(ax, transitions, threshold.*ones(size(transitions)), 'g.', 'linewidth', 10)
                    obj.video.cue.frames = transitions;
                end
            end
		end
		function alignCED_to_video(obj)
			% 
            % need to get CamO nearest to CED lampOff_frames
            %
            if isfield(obj.video,'lampOFF')
	            IRtrig_frame = find(obj.CED.CamO_s >= obj.CED.IRtrig_s, 1, 'first');
	            obj.CED.IRtrig_frame = IRtrig_frame;
            else
            	IRtrigframeCED = find(obj.CED.CamO_s>=obj.CED.IRtrig_s,1,'first');
            	firstCueframeCED = find(obj.CED.CamO_s>=obj.CED.cue_s(1),1,'first');
            	delIRtrig = firstCueframeCED - IRtrigframeCED;
            	obj.video.IRtrig = obj.video.cue.frames(1) - delIRtrig;
            	warning('we''re aligning to the cue')
	            obj.CED.IRtrig_frame = IRtrigframeCED;
                IRtrig_frame = IRtrigframeCED;
        	end
        	% trim off the CED frames so that it matches the video
            if IRtrig_frame-obj.video.IRtrig+1 <= 0
                obj.CED.CamO_s = [nan(-1*(IRtrig_frame-obj.video.IRtrig),1); obj.CED.CamO_s];
                IRtrig_frame = find(obj.CED.CamO_s >= obj.CED.IRtrig_s, 1, 'first');
                obj.CED.IRtrig_frame = IRtrig_frame;
            end
        
            obj.CED.CamO_s_trim = obj.CED.CamO_s(IRtrig_frame-obj.video.IRtrig+1:end);
            % get the timestamps
            for ii = 1:numel(obj.CED.lampOff_s)
            	obj.CED.CamO_trialStart_frames_wrt_IRtrig(ii) = find(obj.CED.CamO_s_trim >= obj.CED.lampOff_s(ii), 1, 'first');
                obj.CED.CamO_lampOff_s_wrt_IRtrig(ii) = obj.CED.CamO_s_trim(obj.CED.CamO_trialStart_frames_wrt_IRtrig(ii));
        	end
        	for ii = 1:numel(obj.CED.lampOn_s)
            	obj.CED.CamO_lampOn_frames_wrt_IRtrig(ii) = find(obj.CED.CamO_s_trim >= obj.CED.lampOn_s(ii), 1, 'first');
                obj.CED.CamO_lampOn_s_wrt_IRtrig(ii) = obj.CED.CamO_s_trim(obj.CED.CamO_lampOn_frames_wrt_IRtrig(ii));
        	end
        	for ii = 1:numel(obj.CED.lick_s)
        		obj.CED.CamO_lick_frames_wrt_IRtrig(ii) = find(obj.CED.CamO_s_trim >= obj.CED.lick_s(ii), 1, 'first');
                obj.CED.CamO_lick_s_wrt_IRtrig(ii) = obj.CED.CamO_s_trim(obj.CED.CamO_lick_frames_wrt_IRtrig(ii));
    		end
    		for ii = 1:numel(obj.CED.cue_s)
        		obj.CED.CamO_cue_frames_wrt_IRtrig(ii) = find(obj.CED.CamO_s_trim >= obj.CED.cue_s(ii), 1, 'first');
                obj.CED.CamO_cue_s_wrt_IRtrig(ii) = obj.CED.CamO_s_trim(obj.CED.CamO_cue_frames_wrt_IRtrig(ii));
            end
            try
	    		t = num2cell(obj.CED.CamO_s_trim(1:numel(obj.videomap))./60);
            catch
    			t = obj.CED.CamO_s_trim(1:end);
                t(end+1:numel(obj.videomap)) = nan;
                t = num2cell(t);
            end
            [obj.videomap.time_min] = t{:};
		end
		function ax = plotTrialStarts(obj, ax)
			%
			%	must run alignCED_to_video and getVideoTrialStartFrames first
			%
			if nargin < 2, ax=[];end
			if ~isfield(obj.iv, 'CUEtriggered')
				threshold = obj.ROIs.lampOFF.threshold;
				ax = obj.plotMeanPixels('lampOFF', ax);
				xx = get(ax, 'xlim');
				% plot the video-found events
				plot(ax, [1, xx(2)], [threshold, threshold], 'r--')
				plot(ax, obj.video.IRtrig, threshold, 'r.', 'markersize', 30, 'displayname', 'IRtrig-video')
				plot(ax, obj.video.lampOFF.frames, threshold.*ones(size(obj.video.lampOFF.frames)), 'r.', 'markersize', 10, 'displayname', 'LampOff-video')
				

				% plot the CED-found events
				plot(ax, obj.CED.CamO_trialStart_frames_wrt_IRtrig, threshold.*ones(size(obj.CED.CamO_trialStart_frames_wrt_IRtrig)), 'bo', 'markersize', 10, 'displayname', 'LampOff-CED')
			else
				threshold = obj.ROIs.cue.threshold;
				ax = obj.plotMeanPixels('cue', ax);
				xx = get(ax, 'xlim');
				% plot the video-found events
				plot(ax, [1, xx(2)], [threshold, threshold], 'r--')
				plot(ax, obj.ROIs.cue.threshold, 'r.', 'markersize', 30, 'displayname', 'Cue-video')
				plot(ax, obj.video.cue.frames, threshold.*ones(size(obj.video.cue.frames)), 'r.', 'markersize', 10, 'displayname', 'Cue-video')
				

				% plot the CED-found events
				plot(ax, obj.CED.CamO_cue_frames_wrt_IRtrig, threshold.*ones(size(obj.CED.CamO_cue_frames_wrt_IRtrig)), 'bo', 'markersize', 10, 'displayname', 'Cue-CED')
			end
			

			title(ax, 'video = r. | CED = bo')
		end
		function trial_starts_in_question = QCvideoTrialStarts_old(obj)
			% 
			% 	asks the min time between trials with CED then finds any events less than that with cam
			% 
			mintrial_in_frames = min(obj.CED.CamO_trialStart_frames_wrt_IRtrig(2:end) - obj.CED.CamO_trialStart_frames_wrt_IRtrig(1:end-1));
			trial_lengths_in_frames_camera = (obj.video.lampOFF.frames(2:end) - obj.video.lampOFF.frames(1:end-1))';
			trial_starts_in_question = obj.video.lampOFF.frames(find(trial_lengths_in_frames_camera<mintrial_in_frames)+1);
		end
		function UIcleanUpTrialStarts_old(obj)
			% ask user to clean up the data by presenting it as figs and
            % asking for a decision
            %
            % start by getting disagreements:
            trial_starts_in_question = obj.QCvideoTrialStarts;
            ax = obj.plotTrialStarts;
            while ~isempty(trial_starts_in_question)
            	disp(['Uh oh! we have ' num2str(numel(trial_starts_in_question)) ' discrepancies with CED'])
            	% show bad trials till we reject
            	for ii = 1:numel(trial_starts_in_question)
	            	xlim(ax, [trial_starts_in_question(ii)-70,trial_starts_in_question(ii)+70])
                    yy = get(ax, 'ylim');
                    plot(ax, [trial_starts_in_question(ii), trial_starts_in_question(ii)],yy, 'r--')
	            	% ask user whether to accept or reject
	            	answer = questdlg('Reject this trial-start event?');
	            	if strcmp(answer, 'Yes')
	            		obj.video.lampOFF.frames(obj.video.lampOFF.frames == trial_starts_in_question(ii)) = [];
	            		break
	        		elseif strcmp(answer, 'Cancel')
	        			return
	    			end
    			end
    			trial_starts_in_question = obj.QCvideoTrialStarts;
        	end
		end
       
        function [trial_starts_in_question, frames_starts_in_question] = QCvideoTrialStarts(obj, useIRtrig)
			% 
			% 	Find any trial-starts in CED not matched by a camera trial start.
			% 
			if nargin<2, useIRtrig = true;end
			if useIRtrig
				CEDtrialstarts_not_found_by_camera = find(...
					~ismember(obj.CED.CamO_trialStart_frames_wrt_IRtrig, obj.video.lampOFF.frames)...
				 & ~ismember(obj.CED.CamO_trialStart_frames_wrt_IRtrig, obj.video.lampOFF.frames+1)...
				 & ~ismember(obj.CED.CamO_trialStart_frames_wrt_IRtrig, obj.video.lampOFF.frames+2)...
				 & ~ismember(obj.CED.CamO_trialStart_frames_wrt_IRtrig, obj.video.lampOFF.frames-1)...
				 & ~ismember(obj.CED.CamO_trialStart_frames_wrt_IRtrig, obj.video.lampOFF.frames-2));
	            frames_starts_in_question = obj.CED.CamO_trialStart_frames_wrt_IRtrig(CEDtrialstarts_not_found_by_camera);
				% CEDtrialstarts_not_found_by_camera = find(~ismembertol(obj.CED.CamO_trialStart_frames_wrt_IRtrig, obj.video.lampOFF.frames, 1));
			else
				CEDtrialstarts_not_found_by_camera = find(...
					~ismember(obj.CED.CamO_cue_frames_wrt_IRtrig, obj.video.cue.frames)...
				 & ~ismember(obj.CED.CamO_cue_frames_wrt_IRtrig, obj.video.cue.frames+1)...
				 & ~ismember(obj.CED.CamO_cue_frames_wrt_IRtrig, obj.video.cue.frames+2)...
				 & ~ismember(obj.CED.CamO_cue_frames_wrt_IRtrig, obj.video.cue.frames-1)...
				 & ~ismember(obj.CED.CamO_cue_frames_wrt_IRtrig, obj.video.cue.frames-2));
	            frames_starts_in_question = obj.CED.CamO_cue_frames_wrt_IRtrig(CEDtrialstarts_not_found_by_camera);
				% CEDtrialstarts_not_found_by_camera = find(~ismembertol(obj.CED.CamO_trialStart_frames_wrt_IRtrig, obj.video.lampOFF.frames, 1));
			end
			trial_starts_in_question = CEDtrialstarts_not_found_by_camera;
        end
        function slideCED(obj, trialNo, nframestoslide)
            %
            %   Have a CED file slightly misaligned? Try shifting around
            %   the CED in increments of 10 or -10 to try to get it better
            %   aligned with video
            %
            obj.CED.CamO_s_trim(obj.CED.CamO_s_trim>obj.CED.cue_s(trialNo)) = obj.CED.CamO_s_trim(obj.CED.CamO_s_trim>obj.CED.cue_s(trialNo)) - nframestoslide*0.033333;
            obj.getVideoLicks;
            obj.gatherLicks;
            obj.plotLicksByTime;
            ylim([trialNo-10,trialNo+10])
        end
		function shiftFrame(obj, CEDframe, VideoFrame, trialNo)
			% 
			% 	The goal here is to backfill frames to all video fields such that the 
			%	video frame specified is now the same as the CEDframe specified
			%
			%	We will establish that anything happening after the og videoframe is now BLIND
			%	and leading up to the new videoframe=CEDframe is blind
			%
			warning('drop a pause sign here so that we can check the video frame we want to correct to')
			% 
			% 	start with the difference between the two frames
			% 
			n_missed_frames = CEDframe - VideoFrame;

			% if this is a negative number, we are undoing something. We can just append to CED?
			if n_missed_frames < 0
				n_missed_frames = -1*n_missed_frames;
				warning('rbf')	
				obj.CED.CamO_trialStart_frames_wrt_IRtrig(obj.CED.CamO_trialStart_frames_wrt_IRtrig>CEDframe) = obj.CED.CamO_trialStart_frames_wrt_IRtrig(obj.CED.CamO_trialStart_frames_wrt_IRtrig>CEDframe) + n_missed_frames;
				obj.CED.CamO_cue_frames_wrt_IRtrig(obj.CED.CamO_cue_frames_wrt_IRtrig>CEDframe) = obj.CED.CamO_cue_frames_wrt_IRtrig(obj.CED.CamO_cue_frames_wrt_IRtrig>CEDframe) + n_missed_frames;
				obj.CED.CamO_lampOn_frames_wrt_IRtrig(obj.CED.CamO_lampOn_frames_wrt_IRtrig>CEDframe) = obj.CED.CamO_lampOn_frames_wrt_IRtrig(obj.CED.CamO_lampOn_frames_wrt_IRtrig>CEDframe) + n_missed_frames;
				obj.CED.CamO_lick_frames_wrt_IRtrig(obj.CED.CamO_lick_frames_wrt_IRtrig>CEDframe) = obj.CED.CamO_lick_frames_wrt_IRtrig(obj.CED.CamO_lick_frames_wrt_IRtrig>CEDframe) + n_missed_frames;				
                obj.CED.CamO_s_trim(obj.CED.CamO_s_trim>obj.CED.cue_s(trialNo)) = obj.CED.CamO_s_trim(obj.CED.CamO_s_trim>obj.CED.cue_s(trialNo)) - 0.033333*n_missed_frames;
			else		
				if ~isfield(obj.iv, 'frameshift')
					obj.iv.frameshift(1).trialNo = trialNo;
					obj.iv.frameshift(1).n_missed_frames = n_missed_frames;
					firstShift = true;
				else
					obj.iv.frameshift(end+1).trialNo = trialNo;
					obj.iv.frameshift(end).n_missed_frames = n_missed_frames;
					firstShift = false;
				end
				% if n_missed_frames <=0, error('there are more video frames than CED frames? This can''t be possible.'), end
				%
				%
				%   go through the video struct and increment all values > video_frame by this difference
				%
				if firstShift
					obj.analysis.video.lick.og_mean_pixels = obj.video.lick.mean_pixels;
					if isfield(obj.video, 'cue')
						obj.analysis.video.cue.og_mean_pixels = obj.video.cue.mean_pixels;
						obj.analysis.video.cue.og_frames = obj.video.cue.frames;
					end
					if isfield(obj.video, 'lampOFF')
	                    if isfield(obj.video.lampOFF, 'mean_pixels')
						    obj.analysis.video.lampOFF.og_mean_pixels = obj.video.lampOFF.mean_pixels;
	                    end
						obj.analysis.video.lampOFF.og_frames = obj.video.lampOFF.frames;
					end

					obj.analysis.videomap.og_time_min = [obj.videomap.time_min];
				end
				obj.video.lick.mean_pixels = [obj.video.lick.mean_pixels(1:VideoFrame-1); nan(n_missed_frames,1); obj.video.lick.mean_pixels(VideoFrame:end)];
				if isfield(obj.video, 'cue')
					obj.video.cue.mean_pixels = [obj.video.cue.mean_pixels(1:VideoFrame-1); nan(n_missed_frames,1); obj.video.cue.mean_pixels(VideoFrame:end)];
					obj.video.cue.frames(obj.video.cue.frames>=VideoFrame) = obj.video.cue.frames(obj.video.cue.frames>=VideoFrame) + n_missed_frames;
				end
				if isfield(obj.video, 'lampOFF')
	                if isfield(obj.video.lampOFF, 'mean_pixels')
					    obj.video.lampOFF.mean_pixels = [obj.video.lampOFF.mean_pixels(1:VideoFrame-1); nan(n_missed_frames,1); obj.video.lampOFF.mean_pixels(VideoFrame:end)];
	                end
					obj.video.lampOFF.frames(obj.video.lampOFF.frames>=VideoFrame) = obj.video.lampOFF.frames(obj.video.lampOFF.frames>=VideoFrame) + n_missed_frames;
				end
				%
				%
				%	also need to increment timestamps from here forward to match. 
				%	CEDframe should correspond to CamO_s at that index. 
				%	So we should be able to update the times in the videomap with this
				%
				
				[obj.videomap(VideoFrame+1:end).time_min] = deal(nan);
				if numel(obj.CED.CamO_s_trim(CEDframe:end)) < numel(obj.videomap) - VideoFrame
	                temp = num2cell(obj.CED.CamO_s_trim(CEDframe:end));
					[obj.videomap(VideoFrame+1:VideoFrame+numel(temp)).time_min] = temp{:};
	            else
	                temp = num2cell(obj.CED.CamO_s_trim(CEDframe:numel(obj.videomap)));
					[obj.videomap(VideoFrame+1:VideoFrame+numel(temp)).time_min] = temp{:};
				end
			end

			%

		end
		function detectFrameShift(obj, Style)
			% 
			% 	We will check the timestamps of cue or lamp off events against CED
			% 
			if strcmpi(Style, 'lampOFF')
                lampOff_CED_frames = obj.CED.CamO_trialStart_frames_wrt_IRtrig;
                lampOff_video_frames = obj.video.lampOFF.frames;
				Event_CED = lampOff_CED_frames;
				Event_video = lampOff_video_frames;
			elseif strcmpi(Style, 'cue')
				cue_CED_frames = obj.CED.CamO_cue_frames_wrt_IRtrig;
                cue_video_frames = obj.video.cue.frames;
                Event_CED = cue_CED_frames;
				Event_video = cue_video_frames;
			end

			for itrial = 1:numel(obj.CED.lampOff_s)
				% find the nearest video event to the CED event
                try
    				video_event_this_trial(itrial) = Event_video(find(Event_video <= Event_CED(itrial) + 2, 1, 'last'));
                catch
                    video_event_this_trial(itrial) = nan;
                end
                if itrial<numel(obj.CED.cue_s)
				    ced_event_this_trial(itrial) = Event_CED(itrial);
                else
                    ced_event_this_trial(itrial) = nan;
                end
			end
			obj.analysis.event_discrepancy = ced_event_this_trial-video_event_this_trial;
			obj.analysis.video_event_this_trial = video_event_this_trial;
			obj.analysis.ced_event_this_trial = ced_event_this_trial;
		end
		function manualShiftTrialStarts(obj, trialNo, nframestoshift)
            if nargin < 3
                %we will figure this out from the flick
                nframestoshift = obj.CED.flickswrtc_frames(trialNo) - obj.video.flickswrtc_frames(trialNo) -1;
                % if nframestoshift <=0, error('We shouldn''t get this, check with Allison');end
                warning(['we''re using first-lick to re-align. we are shifting CED forward by ' num2str(nframestoshift) ' frames'])
            end
			% use this after gotten to the stage with lick raster
			if isfield(obj.iv, 'CUEtriggered')
				% use cue to shift
				% trialStartsCED = obj.CED.CamO_cue_frames_wrt_IRtrig;
				trialStartsVideo = obj.video.cue.frames;
				VideoFrame = trialStartsVideo(trialNo);
                CEDframe = VideoFrame+nframestoshift;
			else % use houselamp
				% trialStartsCED = obj.CED.CamO_trialStart_frames_wrt_IRtrig;
				trialStartsVideo = obj.video.lampOFF.frames;
				VideoFrame = trialStartsVideo(trialNo);
                CEDframe = VideoFrame+nframestoshift;
			end
			obj.shiftFrame(CEDframe, VideoFrame, trialNo);
			% now we have to update the trial starts...
            if isfield(obj.iv, 'CUEtriggered')
    			obj.video.cue.frames(trialNo:end) = obj.video.cue.frames(trialNo:end)+nframestoshift;
            end
			obj.video.lampOFF.frames(trialNo:end) = obj.video.lampOFF.frames(trialNo:end)+nframestoshift;
			% and time in sec (also shifts cue and lampoff)
			obj.getVideoLicks;
			obj.gatherLicks;
			% replot raster to check work
			obj.plotLicksByTime;
            ylim([trialNo-10, trialNo+10])
		end
		function UIcleanUpTrialStarts(obj, revise, acceptAll)
			% ask user to clean up the data by presenting it as figs and
            % asking for a decision
            %
            % start by getting disagreements:
            if nargin < 3, acceptAll=false;end
            if nargin < 2, revise = false;end
            if revise
                if isfield(obj.ROIs,'lampOFF')
	                obj.detectFrameShift('lampoff');
                else
            	    obj.detectFrameShift('cue');
                end
            end
            [~,ax] = makeStandardFigure(2,[2,1]);
            ax(1) = obj.plotTrialStarts(ax(1));
            ax(2) = obj.plotTrialStarts(ax(2));
            % find any trials with more than 2 discrepancy
            trials_to_examine = find(obj.analysis.event_discrepancy > 2 | obj.analysis.event_discrepancy < -2);
            disp(['Uh oh! we have ' num2str(numel(trials_to_examine)) ' discrepancies with CED'])
            
            while numel(trials_to_examine) > 0
                trialNo = trials_to_examine(1);
                if ~acceptAll
        	        title(ax(1), ['video judgment: trial ' num2str(trialNo) ' video frame:' num2str(obj.analysis.video_event_this_trial(trialNo))])
	                xlim(ax(1), [obj.analysis.video_event_this_trial(trialNo)-70,obj.analysis.video_event_this_trial(trialNo)+70])
                    yy = get(ax(1), 'ylim');
                    plot(ax(1), [obj.analysis.video_event_this_trial(trialNo), obj.analysis.video_event_this_trial(trialNo)],yy, 'r--', 'displayname', 'CED')
    
                    title(ax(2), ['CED judgment: trial ' num2str(trialNo) ' CED frame:' num2str(obj.analysis.ced_event_this_trial(trialNo))])
	                xlim(ax(2), [obj.analysis.ced_event_this_trial(trialNo)-70,obj.analysis.ced_event_this_trial(trialNo)+70])
                    yy = get(ax(2), 'ylim');
                    plot(ax(2), [obj.analysis.ced_event_this_trial(trialNo), obj.analysis.ced_event_this_trial(trialNo)],yy, 'r--', 'displayname', 'CED')
    
	                % use the CED timestamp?
	                answer = questdlg(sprintf('Y=use CED timestamp this trial\nN=correct frameshift\nCancel to break out'));
	                if strcmp(answer, 'Yes')
		                obj.analysis.video_event_this_trial(trialNo) = obj.analysis.ced_event_this_trial(trialNo);
		                obj.analysis.event_discrepancy = obj.analysis.ced_event_this_trial-obj.analysis.video_event_this_trial;
		                trials_to_examine = find(obj.analysis.event_discrepancy > 2 | obj.analysis.event_discrepancy < -2);
	                elseif strcmp(answer, 'No')
	        	        obj.shiftFrame(obj.analysis.ced_event_this_trial(trialNo), obj.analysis.video_event_this_trial(trialNo),trialNo);
	        	        if isfield(obj.ROIs,'lampOFF')
		                    obj.analysis.video.lampOFF.og_frames = obj.video.lampOFF.frames;
		                    obj.video.lampOFF.frames = [obj.video.lampOFF.frames;obj.analysis.video_event_this_trial'];
	                    else
	            	        obj.analysis.video.cue.og_frames = obj.video.cue.frames;
	            	        obj.video.cue.frames = [obj.video.cue.frames;obj.analysis.video_event_this_trial'];
	        	        end
	        	        
	        	        if isfield(obj.ROIs,'lampOFF')
                            obj.video.lampOFF.frames = sort(unique(obj.video.lampOFF.frames));
	                        obj.detectFrameShift('lampoff');
                        else
                            obj.video.cue.frames = sort(unique(obj.video.cue.frames));
            	            obj.detectFrameShift('cue');
                        end
    
	                elseif strcmp(answer, 'Cancel')
		                return
                    end
                else
                    obj.analysis.video_event_this_trial(trialNo) = obj.analysis.ced_event_this_trial(trialNo);
	                obj.analysis.event_discrepancy = obj.analysis.ced_event_this_trial-obj.analysis.video_event_this_trial;
	                trials_to_examine = find(obj.analysis.event_discrepancy > 2 | obj.analysis.event_discrepancy < -2);
                end
            end
            % now, remove any camera trials starts not in range for CED

            if isfield(obj.ROIs,'lampOFF')
                obj.analysis.video.lampOff.og_frames = obj.video.lampOFF.frames;
        	    obj.video.lampOFF.frames = obj.analysis.video_event_this_trial;
            else
        	    obj.analysis.video.cue.og_frame = obj.video.cue.frames;
        	    obj.video.cue.frames = obj.analysis.video_event_this_trial;
        	    obj.video.lampOFF.frames = obj.video.cue.frames - (obj.CED.CamO_cue_frames_wrt_IRtrig - obj.CED.CamO_trialStart_frames_wrt_IRtrig)+1;
            end

	        
		    ax = obj.plotTrialStarts;
            
            obj.iv.trialsAligned=true;
		end

		function UIcleanUpTrialStartsold2(obj, acceptAll)
			% ask user to clean up the data by presenting it as figs and
            % asking for a decision
            %
            if nargin < 2, acceptAll = false;end
            
            if ~isfield(obj.iv, 'CUEtriggered')
                if acceptAll
                    obj.video.lampOFF.frames(1) = obj.video.IRtrig;
                    obj.video.lampOFF.frames(2:numel(obj.CED.CamO_trialStart_frames_wrt_IRtrig(2:end))+1) = obj.CED.CamO_trialStart_frames_wrt_IRtrig(2:end);
                else
                    % start by getting disagreements:
                    [trial_starts_in_question,frames_starts_in_question] = obj.QCvideoTrialStarts;
                    ax = obj.plotTrialStarts;
        	        disp(['Uh oh! we have ' num2str(numel(trial_starts_in_question)) ' discrepancies with CED'])
        	        % show bad trials till we reject
        	        for ii = 1:numel(trial_starts_in_question)
            	        xlim(ax, [frames_starts_in_question(ii)-70,frames_starts_in_question(ii)+70])
                        yy = get(ax, 'ylim');
                        plot(ax, [frames_starts_in_question(ii), frames_starts_in_question(ii)],yy, 'r--')
            	        % use the CED timestamp?
            	        answer = questdlg('Y=use CED timestamp; N=correct frameshift; Cancel to break out');
            	        if strcmp(answer, 'Yes')
            		        obj.video.lampOFF.frames(end+1) = obj.CED.CamO_trialStart_frames_wrt_IRtrig(trial_starts_in_question(ii));
        		        elseif strcmp(answer, 'No')
        		        	% we will update the video field and break out of the function entirely
        		        	CEDframe_thisTrialStart = obj.CED.CamO_trialStart_frames_wrt_IRtrig(trial_starts_in_question(ii));
        		        	% find the breakpoint
        		        	VideoFrame_thisTrialStart = obj.video.lampOFF.frames(find(obj.video.lampOFF.frames<CEDframe_thisTrialStart, 1, 'last'));
        		        	obj.shiftFrame(CEDframe, VideoFrame);
        		        	disp(['shifted the video fields to account for ' num2str(CEDframe-VideoFrame) 'missed frames. Rerun obj.UIcleanUpTrialStarts to resume.'])
        		        	return
        		        elseif strcmp(answer, 'Cancel')
        			        return
    			        end
			        end
			        % now, remove any camera trials starts not in range for CED
    
			        Camera_trialstarts_not_found_by_CED = (...
				        ~ismember(obj.video.lampOFF.frames, obj.CED.CamO_trialStart_frames_wrt_IRtrig)...
			         & ~ismember(obj.video.lampOFF.frames, obj.CED.CamO_trialStart_frames_wrt_IRtrig+1)...
			         & ~ismember(obj.video.lampOFF.frames, obj.CED.CamO_trialStart_frames_wrt_IRtrig+2)...
			         & ~ismember(obj.video.lampOFF.frames, obj.CED.CamO_trialStart_frames_wrt_IRtrig-1)...
			         & ~ismember(obj.video.lampOFF.frames, obj.CED.CamO_trialStart_frames_wrt_IRtrig-2));
    
			        obj.video.lampOFF.frames(Camera_trialstarts_not_found_by_CED) = [];
    
    
			        close(gcf);
			        disp('Corrected trial starts on camera...')
                    obj.video.lampOFF.frames=sort(obj.video.lampOFF.frames);
                end
			    ax = obj.plotTrialStarts;
            else
                if acceptAll
                    obj.video.cue.frames(1) = obj.video.IRtrig;
                    obj.video.cue.frames(2:numel(obj.CED.CamO_cue_frames_wrt_IRtrig(2:end))+1) = obj.CED.CamO_cue_frames_wrt_IRtrig(2:end);
                else
			        warning('using the cue to align')
			        % start by getting disagreements:
                    [trial_starts_in_question,frames_starts_in_question] = obj.QCvideoTrialStarts(false);
                    ax = obj.plotTrialStarts;
        	        disp(['Uh oh! we have ' num2str(numel(trial_starts_in_question)) ' discrepancies with CED'])
        	        % show bad trials till we reject
        	        for ii = 1:numel(trial_starts_in_question)
            	        xlim(ax, [frames_starts_in_question(ii)-70,frames_starts_in_question(ii)+70])
                        yy = get(ax, 'ylim');
                        plot(ax, [frames_starts_in_question(ii), frames_starts_in_question(ii)],yy, 'r--')
            	        % use the CED timestamp?
            	        answer = questdlg('Use CED timestamp for this trial?');
            	        if strcmp(answer, 'Yes')
            		        obj.video.cue.frames(end+1) = obj.CED.CamO_cue_frames_wrt_IRtrig(trial_starts_in_question(ii));
        		        elseif strcmp(answer, 'Cancel')
        			        return
    			        end
			        end
			        % now, remove any camera trials starts not in range for CED
    
			        Camera_trialstarts_not_found_by_CED = (...
				        ~ismember(obj.video.cue.frames, obj.CED.CamO_cue_frames_wrt_IRtrig)...
			         & ~ismember(obj.video.cue.frames, obj.CED.CamO_cue_frames_wrt_IRtrig+1)...
			         & ~ismember(obj.video.cue.frames, obj.CED.CamO_cue_frames_wrt_IRtrig+2)...
			         & ~ismember(obj.video.cue.frames, obj.CED.CamO_cue_frames_wrt_IRtrig-1)...
			         & ~ismember(obj.video.cue.frames, obj.CED.CamO_cue_frames_wrt_IRtrig-2));
    
			        obj.video.cue.frames(Camera_trialstarts_not_found_by_CED) = [];
    
    
			        close(gcf);
			        disp('Corrected trial starts on camera...')
                    obj.video.cue.frames=sort(obj.video.cue.frames);
                end
			    ax = obj.plotTrialStarts;
            end
            obj.iv.trialsAligned=true;
		end
		function getVideoLicks(obj)
			% 
			% 	Once we have set a threshold in LampOff ROI field, we can assign trial start events
			% 
			threshold = obj.ROIs.lick.threshold;
			lick_logic = obj.video.lick.mean_pixels > threshold;
            all_transitions = (lick_logic(2:end) -  lick_logic(1:end-1));
            up_transitions = all_transitions ==1;
			transitions = find(up_transitions) - 1;%find(down_transitions & ~neighbor_up_transitions) + 1;
			ax = obj.plotMeanPixels('lick');
			xx = get(ax, 'xlim');
			plot(ax, [1, xx(2)], [threshold, threshold], 'r--')
			plot(ax, transitions+2, threshold.*ones(size(transitions)), 'g.', 'linewidth', 10)
            obj.video.lick.frames = transitions+1;
		end
		function getVideoEventsInCEDsec(obj)
            if isfield(obj.video.lampOFF, 'mean_pixels')
    			nframes = numel(obj.video.lampOFF.mean_pixels);
            else
                nframes = numel(obj.video.cue.mean_pixels);
            end
			if nframes > numel(obj.CED.CamO_s_trim), nframes = numel(obj.CED.CamO_s_trim);end
			obj.video.frames_s = obj.CED.CamO_s_trim(1:nframes);
            if isfield(obj.video.lampOFF, 'mean_pixels')
                try
    			    obj.video.lampOFF.s = obj.video.frames_s(obj.video.lampOFF.frames);
                catch
                    warning('we dont have the full video')
                    obj.video.lampOFF.s = obj.video.frames_s(obj.video.lampOFF.frames(1:find(obj.video.lampOFF.frames<=numel(obj.video.frames_s), 1, 'last')));
                end
            else
                obj.video.lampOFF.s = obj.CED.CamO_trialStart_frames_wrt_IRtrig;
            end
			obj.video.lick.s = obj.video.frames_s(obj.video.lick.frames(1:sum(obj.video.lick.frames<numel(obj.video.frames_s))));
		end
		function gatherLicks(obj)
			% 	first run obj.getVideoLicks
			obj.getVideoEventsInCEDsec;
			% 
			% 
			% 	we will attempt to identify all first-licks that are in agreement with CED and video
			% 
			if ~obj.iv.trialsAligned && ~isempty(QCvideoTrialStarts(obj)), error('you must first QC the trial times with obj.UIcleanUpTrialStarts'), end
			% 
			% 	Start by getting flickswrtc for CED and video
			% 
			% 	Video licks in frames
			% 
			[lick_bt, lick_bt_wrtc, flickswrtc] = binupspikes(obj.video.lick.frames, obj.video.lampOFF.frames,50, 600);
			obj.video.lick_bt_frames = lick_bt;
			obj.video.lick_bt_wrtlo_frames = lick_bt_wrtc;
			obj.video.flickswrtlo_frames = flickswrtc;
			[lick_bt, lick_bt_wrtc, flickswrtc] = binupspikes(obj.video.lick.frames, obj.CED.CamO_cue_frames_wrt_IRtrig,50, 600);
			obj.video.lick_bt_frames = lick_bt;
			obj.video.lick_bt_wrtc_frames = lick_bt_wrtc;
			obj.video.flickswrtc_frames = flickswrtc;
			% 
			% 	Video licks in sec
			% 
			[lick_bt, lick_bt_wrtc, flickswrtc] = binupspikes(obj.video.lick.s, obj.video.lampOFF.s,3, 18.5);
			obj.video.lick_bt_s = lick_bt;
			obj.video.lick_bt_wrtlo_s = lick_bt_wrtc;
			obj.video.flickswrtlo_s = flickswrtc;
			[lick_bt, lick_bt_wrtc, flickswrtc] = binupspikes(obj.video.lick.s, obj.CED.CamO_cue_s_wrt_IRtrig,3, 18.5);
			obj.video.lick_bt_s = lick_bt;
			obj.video.lick_bt_wrtc_s = lick_bt_wrtc;
			obj.video.flickswrtc_s = flickswrtc;
			% obj.plotraster(lick_bt_wrtc, flickswrtc, 'ax', ax(2), 'dispName', 'Video', 'markersize', 10, 'append', false, 'color', [0,1,0], 'referenceEventName', 'Cue');
			% 
			% CED CamO licks in frames
			%
			[lick_bt, lick_bt_wrtc, flickswrtc] = binupspikes(obj.CED.CamO_lick_frames_wrt_IRtrig, obj.CED.CamO_trialStart_frames_wrt_IRtrig,50, 600);
			obj.CED.lick_bt_frames = lick_bt;
			obj.CED.lick_bt_wrtlo_frames = lick_bt_wrtc;
			obj.CED.flickswrtlo_frames = flickswrtc;
			[lick_bt, lick_bt_wrtc, flickswrtc] = binupspikes(obj.CED.CamO_lick_frames_wrt_IRtrig, obj.CED.CamO_cue_frames_wrt_IRtrig,50, 600);
			obj.CED.lick_bt_frames = lick_bt;
			obj.CED.lick_bt_wrtc_frames = lick_bt_wrtc;
			obj.CED.flickswrtc_frames = flickswrtc;
			% 
			% CED CamO licks in s
			%
			[lick_bt, lick_bt_wrtc, flickswrtc] = binupspikes(obj.CED.CamO_lick_s_wrt_IRtrig, obj.CED.CamO_lampOff_s_wrt_IRtrig,3, 18.5);
			obj.CED.lick_bt_s = lick_bt;
			obj.CED.lick_bt_wrtlo_s = lick_bt_wrtc;
			obj.CED.flickswrtlo_s = flickswrtc;
			[lick_bt, lick_bt_wrtc, flickswrtc] = binupspikes(obj.CED.CamO_lick_s_wrt_IRtrig, obj.CED.CamO_cue_s_wrt_IRtrig,3, 18.5);
			obj.CED.lick_bt_s = lick_bt;
			obj.CED.lick_bt_wrtc_s = lick_bt_wrtc;
			obj.CED.flickswrtc_s = flickswrtc;
			% obj.plotraster(lick_bt_wrtc, flickswrtc, 'ax', ax(2), 'dispName', 'CED CamO', 'markersize', 5, 'append', true, 'color', [0,0,0]);
		end
		function plotLicksByFrames(obj)
			[f,ax] = makeStandardFigure;%(2, [1,2]);
			obj.plotraster(obj.video.lick_bt_wrtc_frames, obj.video.flickswrtc_frames, 'ax', ax(1), 'dispName', 'Video', 'markersize', 10, 'append', false, 'color', [0,1,0], 'referenceEventName', 'Cue');
			obj.plotraster(obj.CED.lick_bt_wrtc_frames, obj.CED.flickswrtc_frames, 'ax', ax(1), 'dispName', 'CED CamO', 'markersize', 5, 'append', true, 'color', [0,0,0]);
            xlabel('Frames with respect to Cue')
        end
       
		function plotLicksByTime(obj)
			[f,ax] = makeStandardFigure;%(2, [1,2]);
			obj.plotraster(obj.video.lick_bt_wrtc_s, obj.video.flickswrtc_s, 'ax', ax(1), 'dispName', 'Video', 'markersize', 10, 'append', false, 'color', [0,1,0], 'referenceEventName', 'Cue');
			obj.plotraster(obj.CED.lick_bt_wrtc_s, obj.CED.flickswrtc_s, 'ax', ax(1), 'dispName', 'CED CamO', 'markersize', 5, 'append', true, 'color', [0,0,0]);
			if isfield(obj.iv,'frameshift')
				xx = get(ax, 'xlim');
				for ii = 1:numel(obj.iv.frameshift)
					plot(ax, xx, [obj.iv.frameshift(ii).trialNo,obj.iv.frameshift(ii).trialNo], 'r--', 'displayname', ['frameshift | n=' num2str(obj.iv.frameshift(ii).n_missed_frames)])
				end
			end
		end
        function ax = plotraster(obj, spikes_wrt_event, first_spike_wrt_event, varargin)
            p = inputParser;
            addParameter(p, 'ax', [], @isaxes); 
            addParameter(p, 'markerSize', 5, @isnumeric); 
            addParameter(p, 'dispName', 'data', @ischar);
            addParameter(p, 'Color', [0,0,0], @isnumeric);
            addParameter(p, 'referenceEventName', 'Reference Event', @ischar);
            addParameter(p, 'append', false, @islogical);
            addParameter(p, 'plotFirst', true, @islogical);
            parse(p, varargin{:});
            ax      = p.Results.ax;
            markerSize      = p.Results.markerSize;
            dispName        = p.Results.dispName;
            Color           = p.Results.Color;
            ReferenceEventName  = p.Results.referenceEventName;
            append          = p.Results.append;
            plotFirst       = p.Results.plotFirst;
            if isempty(ax), [~, ax] = makeStandardFigure();end
            % 
            %   Plot raster of all licks with first licks overlaid
            % 
            numRefEvents = numel(first_spike_wrt_event);
            if ~append
                plot(ax, [0,0], [1,numRefEvents],'r-', 'DisplayName', ReferenceEventName)
                set(ax,  'YDir','reverse')
                ylim(ax, [1, numRefEvents])
            end
            if plotFirst % plot the first event after the cue
                plot(ax, first_spike_wrt_event, 1:numRefEvents, '.', 'color', Color, 'markersize', markerSize+10, 'DisplayName', dispName);
            end
            
        %   for iexc = obj.iv.exclusions_struct.Excluded_Trials
        %       spikes_wrt_event{iexc} = [];
        %     end
            for itrial = 1:numRefEvents
                plotpnts = spikes_wrt_event{itrial};
                if ~isempty(plotpnts)
                    if ~plotFirst && itrial==1
                        plot(ax, plotpnts, itrial.*ones(numel(plotpnts), 1), '.', 'color', Color,  'markerSize', markerSize, 'DisplayName', dispName)
                    else
                        plot(ax, plotpnts, itrial.*ones(numel(plotpnts), 1),'.', 'color', Color,  'markerSize', markerSize, 'handlevisibility', 'off')
                    end
                end
            end 
            yy = get(ax, 'ylim');
            ylim(ax, yy);
            legend(ax,'show', 'location', 'best')
            ylabel(ax,[ReferenceEventName, ' #'])
            xlabel(ax,['Time (s) wrt ' ReferenceEventName])
        end
        function [ax,CED1st, Video1st] = timeseriesROIcomparison(obj, trialNo, ax)
        	% 
        	% 	Use this to look for issues between CED/video on individual trials
        	% 
        	% get the fame of the lampOff event for this trial
        	frame_LO = obj.video.lampOFF.frames(trialNo);
        	if ~isfield(obj.video,'cue')
	        	frame_cue = obj.CED.CamO_cue_frames_wrt_IRtrig(trialNo);
        	else
        		frame_cue = obj.video.cue.frames(trialNo);
    		end
        	if nargin < 3, [f,ax] = makeStandardFigure(2, [2,1]);set(f, 'units', 'normalized', 'position', [ 0    0.4456    0.5583    0.4667]);end
        	
        	if isfield(obj.ROIs, 'lampOFF')
        		Limits = max([1,frame_LO-50-600]): min([frame_LO+600+600, numel(obj.video.lampOFF.mean_pixels)]);
                obj.plotMeanPixels('lampoff', ax(1), Limits);
                xx = get(ax(1),'xlim');
                plot(ax(1), xx, [obj.ROIs.lampOFF.threshold, obj.ROIs.lampOFF.threshold], 'm--')
        	    ylabel(ax(1), 'lampOff ROI')
            else
            	Limits = max([1,frame_LO-50-600]): min([frame_LO+600+600, numel(obj.video.cue.mean_pixels)]);
                obj.plotMeanPixels('cue', ax(1), Limits);
                xx = get(ax(1),'xlim');
                plot(ax(1), xx, [obj.ROIs.cue.threshold, obj.ROIs.cue.threshold], 'm--')
        	    ylabel(ax(1), 'cue ROI')
            end
        	title(ax(1), ['Trial #' num2str(trialNo)])
        	obj.plotMeanPixels('lick', ax(2), Limits);
            plot(ax(2), xx, [obj.ROIs.lick.threshold, obj.ROIs.lick.threshold], 'm--')
        	ylabel(ax(2), 'lick ROI')
        	title(ax(2), '')    		
        	for ii=1:2
        		xlim(ax(ii), [frame_LO-600, frame_LO+600])
        		yy = get(ax(ii), 'ylim');
        		plot(ax(ii), [frame_LO,frame_LO], yy, 'r--')
                plot(ax(ii), [frame_cue,frame_cue], yy, 'r.-')
        		% pp = [[obj.video.lick_bt_wrtc_frames{trialNo}+frame_cue;obj.video.lick_bt_wrtc_frames{trialNo}+frame_cue],[yy(1).*ones(size(obj.video.lick_bt_wrtc_frames{trialNo}));yy(2).*ones(size(obj.video.lick_bt_wrtc_frames{trialNo}))]];
                xs = obj.video.lick_bt_wrtlo_frames{trialNo}+frame_LO;%obj.video.lick_bt_wrtlo_frames{trialNo}+frame_LO];
        		if ~isempty(xs)
        			xline(ax(ii), xs, 'g-', 'linewidth', 1)
        		end

    			% xs = obj.CED.lick_bt_wrtlo_frames{trialNo}+frame_LO;%obj.CED.lick_bt_wrtlo_frames{trialNo}+frame_LO];
        		% if ~isempty(xs),xline(ax(ii), xs, 'k-'), end
        		lickframes_ced = obj.CED.lick_bt_wrtc_frames{trialNo}+frame_cue;
        		if ~isempty(xs)
        			xline(ax(ii), lickframes_ced, 'k-', 'linewidth', 1)
        		end
                ylim(ax(ii),yy)
        		% plot(ax(ii), [yy(1).*ones(numel(obj.video.lick_bt_wrtc_frames{trialNo});yy(2).*ones(numel(obj.video.lick_bt_wrtc_frames{trialNo})],[obj.video.lick_bt_wrtc_frames{trialNo};obj.video.lick_bt_wrtc_frames{trialNo}], yy, 'r--')
    		end

    		Video1st = obj.video.flickswrtc_frames(trialNo);
    		CED1st = obj.CED.flickswrtc_frames(trialNo);

    		linkaxes(ax, 'x');
    	end
    	function [trials_to_examine, differences] = findLickTimeDiscrepancies(obj, threshold_to_examine, differences)
    		if nargin < 2, threshold_to_examine = 0.25;end % this seems to be conservative based on hxg
    		% 
    		% 	Once we have all our lick data, we can compare video to CED judgments to ID trials to examine
    		% 
    		if nargin < 3
	    		differences = obj.video.flickswrtc_s - obj.CED.flickswrtc_s;
	    		% [f,ax] = makeStandardFigure;
	    		% prettyHxg(ax, differences, 'del(video - CED)', 'r', -18:0.25:18, []);
    		end
    		trials_to_examine = find(abs(differences) > threshold_to_examine);
    		if ~isempty(trials_to_examine), disp([' *** uh-oh! we found ' num2str(numel(trials_to_examine)) ' trials with first-lick time discrepancies']);end
			obj.analysis.differences = differences;
			obj.analysis.trials_to_examine = trials_to_examine;
		end
		function UIexamineLicking(obj,threshold_to_examine, redo)
			if nargin < 3, redo = false;end
			if nargin < 2, threshold_to_examine = 0.1;end
			disp([' ==> Examining differences in lick-time between CED/video, threshold difference = ' num2str(threshold_to_examine), 's'])
			obj.findLickTimeDiscrepancies(threshold_to_examine);

			if redo
				CED_missed_trials = [];
				obj.analysis.CED_missed_trials = [];
				obj.analysis.video_missed_trials = [];
				obj.analysis.groomingTrials = [];
				obj.analysis.okTrials = [];
				video_missed_trials = [];
				groomingTrials = [];
				okTrials = [];
			else
				CED_missed_trials = obj.analysis.CED_missed_trials;
				video_missed_trials = obj.analysis.video_missed_trials;
				groomingTrials = obj.analysis.groomingTrials;
				okTrials = obj.analysis.okTrials;

				alreadylabeled = [CED_missed_trials,video_missed_trials,groomingTrials,okTrials];
				obj.analysis.trials_to_examine(ismember(obj.analysis.trials_to_examine, alreadylabeled)) = [];
				warning('rbf')
			end
			for ii = 1:numel(obj.analysis.trials_to_examine)
				trialNo = obj.analysis.trials_to_examine(ii);
				% find out if CED or video missed
				if obj.analysis.differences(trialNo) > 0 % video missed
					frameNo_missedLick = round(obj.CED.CamO_lick_s_wrt_IRtrig(find(obj.CED.CamO_lick_s_wrt_IRtrig > obj.CED.CamO_cue_frames_wrt_IRtrig(trialNo),1, 'first')));  
					Str = ['video flickswrtcs = ', num2str(obj.video.flickswrtc_s(trialNo)) '\n',...
                        'CED flickswrtcs = ' num2str(obj.CED.flickswrtc_s(trialNo))];
                elseif obj.analysis.differences(trialNo) < 0 % CED missed
					frameNo_missedLick = obj.video.lick.frames(find(obj.video.lick.frames > obj.CED.CamO_cue_frames_wrt_IRtrig(trialNo),1, 'first'));
					Str = ['video flickswrtcs = ', num2str(obj.video.flickswrtc_s(trialNo)) '\n',...
                        'CED flickswrtcs = ' num2str(obj.CED.flickswrtc_s(trialNo))];
                else
                    okTrials(end+1) = trialNo;
                    continue
                end
                if isempty(frameNo_missedLick), frameNo_missedLick = obj.video.lick.frames(find(obj.video.lick.frames > obj.CED.CamO_cue_frames_wrt_IRtrig(trialNo),1, 'first'));end
                % frameNo_missedLick = obj.video.flickswrtc_frames(trialNo) + obj.CED.CamO_cue_frames_wrt_IRtrig(trialNo);

				[ax, CED1st, Video1st] = obj.timeseriesROIcomparison(trialNo);
				try
                    xlim(ax(1), [obj.video.lampOFF.frames(trialNo)-10, obj.CED.CamO_lampOn_frames_wrt_IRtrig(trialNo)+50])
                catch
                    warning('there''s an issue with ced/cam alignment')
                end
				if Video1st == CED1st || Video1st == CED1st+1 || Video1st == CED1st-1
					disp('Looks good! proceeding')
					okTrials(end+1) = trialNo;
					obj.analysis.okTrials(end+1) = trialNo;
					close all
					continue
				end
                
				f_ROI = gcf;
                ax2 = obj.plot(frameNo_missedLick);
                f_mus = gcf;
                [f_mus2,ax3] = makeStandardFigure(3, [1, 3]);
                set(f_mus2, 'Position', [0.0639         0    0.9361    0.3856])
				ax3(1) = obj.plot(frameNo_missedLick, ax3(1));
                ax3(2) = obj.plot(frameNo_missedLick+1, ax3(2));
                ax3(3) = obj.plot(frameNo_missedLick+2, ax3(3));
				
				t = ax2.Title.String;
				t = sprintf([t, '\n', Str]);
                title(ax2, t);
				% answer = questdlg('How should this trial be categorized?',['Suspect trial ' num2str(ii) '/' num2str(numel(obj.analysis.trials_to_examine))],...
				% 	'Missed Lick (CED or Video)',...
				% 	'Grooming',...
				% 	'Ok',...
				% 	'Grooming');
                obj.plotLicksByTime;
                ylim([trialNo-5, trialNo+5])
				answer = NonmodalQuestdlg([ 0.55 , 0.85 ],'How should this trial be categorized?',['Suspect trial ' num2str(ii) '/' num2str(numel(obj.analysis.trials_to_examine))],...
					'Missed Lick (CED)',...
					'Grooming',...
					'Ok',...
					'Grooming');
				if strcmp(answer, 'Missed Lick (CED)')
					% if obj.analysis.differences(trialNo) > 0
					% 	video_missed_trials(end+1) = trialNo;
					% 	obj.analysis.video_missed_trials(end+1) = trialNo;
					% else
						CED_missed_trials(end+1) = trialNo;
						obj.analysis.CED_missed_trials(end+1) = trialNo;
					% end
				elseif strcmp(answer, 'Grooming')
					groomingTrials(end+1) = trialNo;
					obj.analysis.groomingTrials(end+1) = trialNo;
				else
					okTrials(end+1) = trialNo;
					obj.analysis.okTrials(end+1) = trialNo;
				end
				close all
			end

			
			obj.analysis.CED_missed_trials = CED_missed_trials;
			obj.analysis.video_missed_trials = video_missed_trials;
			obj.analysis.groomingTrials = groomingTrials;
			% obj.analysis.OK_Trials = OK_Trials;


			obj.getLickQCSummary();

			obj.save(false)
		end
		function getLickQCSummary(obj)
			CED_missed_trials = obj.analysis.CED_missed_trials;
			groomingTrials = obj.analysis.groomingTrials;
			trialsParticipated = sum(~isnan(obj.CED.flickswrtc_s));

			disp('~~~~~~~~~~~~~~~~~~~~~~~~')
			disp(' Summary:')
            CED_misses = numel(CED_missed_trials);
            Grooming = numel(groomingTrials);
            okTrialsAfterExcludingThese = trialsParticipated - CED_misses - Grooming;
			Summary = table(trialsParticipated,...
				CED_misses,...
                Grooming,...
                okTrialsAfterExcludingThese);
			disp(Summary)
			obj.analysis.Summary = Summary;
		end
	end
end