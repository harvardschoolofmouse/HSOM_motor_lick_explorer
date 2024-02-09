% % video_lick_extractor.m
%

% disp('select video file folder');videofolder = uigetdir('select video file folder');

zoom = 2.5;

% pick out the video
cd(videofolder)
videoidx = dir;
videoidx = videoidx(3:end);

for fileNo = 1:numel(videoidx)
    
    % open the relevant video
    fileName = videoidx(fileNo).name;   
    filePath = [pwd,'/',fileName];
    vid = VideoReader(fileName);
    
    
    frameRate = vid.FrameRate;
    Height = vid.Height;
    Width = vid.Width;
    NumFrames = vid.NumFrames;
    
    AspectRatio = Height/Width;
    
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
    
    %%
    [f,ax] = makeStandardFigure();
    set(f, 'units', 'pixels');
    set(f, 'position', [1600, 0, zoom*Width+125, zoom*Height+125])
    set(ax, 'units', 'pixels')
    set(ax, 'position', [75, 75, zoom*Width, zoom*Height])
    set(f, 'name', [name, ' | video #' num2str(fileNo)])
    set(ax,'YDir','reverse')
    
    mean_pixels = nan(5000,1);
    % for each timepoint, plot the video frame and then overlay the keypoints
    for i_timepoint = 1:5000%NumFrames
        % business of the program...
        % 
        % 
        frame = read(vid, i_timepoint);
        if fileNo == 1 && i_timepoint == 1
            xlim(ax,[0, Width])
            ylim(ax,[0, Height])
            
            hImage = image(frame,"Parent",ax);
            title(['frame #: ' num2str(i_timepoint) ' | time: ' num2str((i_timepoint-1)*frameRate)])
            roi = drawrectangle(ax);
            pos = roi.Position;
            x_ix = round(pos(2):pos(2)+pos(4));
            y_ix = round(pos(1):pos(1)+pos(3));
            figure, imshow(frame(x_ix, y_ix))
        end
        Pixels = frame(x_ix, y_ix);
        mean_pixels(i_timepoint) = mean(mean(Pixels));

        % cla(ax)
    end
    [f,ax] = makeStandardFigure;
    plot(mean_pixels)
    ylabel('intensity')
    xlabel('frame #')
    % close(video); 
end