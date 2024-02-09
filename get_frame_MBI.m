function get_frame_MBI(vid, frameNo, name, fileNo, zoom)
    Width = vid.Width;
    Height = vid.Height;
    frameRate = vid.FrameRate;
    if nargin < 4
        zoom = 2.5;
    end
    
    frame = read(vid, 2683);
    [f,ax] = makeStandardFigure();
    set(f, 'units', 'pixels');
    set(f, 'position', [1600, 0, zoom*Width+125, zoom*Height+125])
    set(ax, 'units', 'pixels')
    set(ax, 'position', [75, 75, zoom*Width, zoom*Height])
    set(f, 'name', [name, ' | video #' num2str(fileNo)])
    set(ax,'YDir','reverse')
    hImage = image(frame,"Parent",ax);
    title(['frame #: ' num2str(frameNo) ' | time: ' num2str(((frameNo-1)/frameRate)/60)])
    xlim(ax,[0, Width])
    ylim(ax,[0, Height])
end