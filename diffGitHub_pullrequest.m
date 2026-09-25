function diffGitHub_pullrequest(branchname)
    proj = openProject(pwd);

    gitCommand = sprintf( ...
        'git --no-pager diff --name-only origin/main..origin/%s', branchname);
    [status, modifiedFiles] = system(gitCommand);

    if status ~= 0
        warning("git diff failed: %s", modifiedFiles);
        return;
    end

    % Split into lines, remove empty, keep only .slx files
    modifiedFiles = strtrim(splitlines(strtrim(modifiedFiles)));
    modifiedFiles = modifiedFiles(~cellfun('isempty', modifiedFiles));
    modifiedFiles = modifiedFiles(endsWith(modifiedFiles, '.slx'));

    if isempty(modifiedFiles)
        disp('No modified .slx models to compare.');
        return
    end

    fprintf('Found %d modified model(s):\n', numel(modifiedFiles));
    for i = 1:numel(modifiedFiles)
        fprintf('  %s\n', modifiedFiles{i});
    end

    % R2023a headless fix: disable screenshots so publish works without display
    % Wrapped in try/catch in case toolbox settings are not registered on runner
    try
        s = settings().comparisons.slx.DisplayReportScreenshots;
        s.TemporaryValue = true;
        disp('DisplayReportScreenshots set to true (headless mode).');
    catch ME
        fprintf('[WARN] Could not set DisplayReportScreenshots: %s\n', ME.message);
        fprintf('[WARN] Report may fail if display is required.\n');
    end

    tempFolder   = fullfile(proj.RootFolder, 'modelscopy');
    reportFolder = proj.RootFolder;
    mkdir(tempFolder);

    for i = 1:numel(modifiedFiles)
        diffToAncestor(tempFolder, reportFolder, modifiedFiles{i});
    end

    rmdir(tempFolder, 's');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function report = diffToAncestor(tempFolder, reportFolder, fileName)
    report = [];
    ancestor = getAncestor(tempFolder, fileName);

    if isempty(ancestor)
        fprintf('Skipping %s — new file, no ancestor on main.\n', fileName);
        return
    end

    fprintf('Comparing : %s\n', fileName);
    fprintf('Ancestor  : %s\n', ancestor);

    try
        comp   = visdiff(ancestor, fileName);
        filter(comp, 'unfiltered');
        
        % FIX: Pass the format explicitly as a Name-Value pair
        report = publish(comp, 'Format', 'pdf', 'OutputFolder', reportFolder);

        
        fprintf('Report written: %s\n', report);
    catch ME
        fprintf('[ERROR] visdiff/publish failed for %s\n', fileName);
        fprintf('Reason  : %s\n', ME.message);
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function ancestor = getAncestor(tempFolder, fileName)
    [~, name, ext] = fileparts(fileName);
    fileName = strrep(fileName, '\', '/');
    ancestor = strrep( ...
        fullfile(tempFolder, [name '_ancestor' ext]), '\', '/');

    gitCommand = sprintf( ...
        'git --no-pager show origin/main:%s > %s', fileName, ancestor);
    [status, ~] = system(gitCommand);

    if status ~= 0
        ancestor = [];
    end
end

%   Copyright 2024-2026 The MathWorks, Inc.
