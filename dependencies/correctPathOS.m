function pathstr = correctPathOS(pathstr, OSspec)
    if nargin < 2, OSspec = false; end
    PC = ispc;
    if strcmpi(OSspec, 'mac'), PC=false; elseif strcmpi(OSspec, 'PC'), PC=true;end
	if PC
		pathstr = strjoin(strsplit(pathstr, '/'), '\');
	else
		pathstr = [strjoin(strsplit(pathstr, '\'), '/')];
	end
end