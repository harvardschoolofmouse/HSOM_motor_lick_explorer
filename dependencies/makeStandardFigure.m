function [f, axs] = makeStandardFigure(naxes,subplots)
	%   [f, axs] = makeStandardFigure(naxes=1,subplots=[1,1])
	% 	subplots is total rows, columns
	% 		e.g., [2,3]
	% 
    if nargin < 2
        naxes = 1;
        subplots = [1,1];
    end
	f = figure;
	set(f, 'color', 'white',...
		'units', 'normalized')
	for ii = 1:naxes
		axs(ii) = subplot(subplots(1), subplots(2),ii);
		hold(axs(ii), 'on');
		set(axs(ii), 'fontsize', 12)
		set(axs(ii), 'tickdir', 'out')
		set(axs(ii), 'ticklength', [0.045,0.055])
		set(axs(ii), 'linewidth', 8)
		set(axs(ii), 'xcolor', 'k')
		set(axs(ii), 'ycolor', 'k')
	end
end