function diffGitHub_pullrequest(branchname)
    proj = openProject(pwd);

    % List modified .slx files between main and the PR branch
    gitCommand = sprintf( ...
        'git --no-pager diff --name-only origin/main..origin/%s', ...
        branchname);
    [status, modifiedFiles] = system(gitCommand);

    if status ~= 0
        warning("git diff failed: %s", modifiedFiles);
        return;
    end

    % Split output into lines and remove empty entries
    modifiedFiles = strtrim(splitlines(strtrim(modifiedFiles)));
    modifiedFiles = modifiedFiles(~cellfun('isempty', modifiedFiles));

    % Keep only .slx files
    isSlx = endsWith(modifiedFiles, '.slx');
    modifiedFiles = modifiedFiles(isSlx);

    if isempty(modifiedFiles)
        disp('No modified .slx models to compare.');
        return
    end

    fprintf('Found %d modified model(s):\n', numel(modifiedFiles));
    for i = 1:numel(modifiedFiles)
        fprintf('  %s\n', modifiedFiles{i});   % cell indexing with {}
    end

    % R2023a FIX: disable screenshots for headless Linux CI runner
    % Without this, publish() fails with "Printing not supported in -nodisplay mode"
    s = settings().comparisons.slx.DisplayReportScreenshots;
    s.TemporaryValue = false;

    % Temp folder for ancestor copies; reports go to project root
    tempFolder  = fullfile(proj.RootFolder, 'modelscopy');
    reportFolder = proj.RootFolder;
    mkdir(tempFolder);

    for i = 1:numel(modifiedFiles)
        diffToAncestor(tempFolder, reportFolder, modifiedFiles{i});
    end

    % Clean up temp folder
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
        % Generate the official MathWorks File Comparison Report
        comp   = visdiff(ancestor, fileName);
        filter(comp, 'unfiltered');
        report = publish(comp, 'html', 'OutputFolder', reportFolder);
        fprintf('Report written: %s\n', report);

    catch ME
        fprintf('[ERROR] visdiff/publish failed for %s\n', fileName);
        fprintf('Reason : %s\n', ME.message);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function ancestor = getAncestor(tempFolder, fileName)
    [~, name, ext] = fileparts(fileName);

    % Normalize path separators for git
    fileName = strrep(fileName, '\', '/');

    % Ancestor file path inside temp folder
    ancestorName = [name, '_ancestor', ext];
    ancestor     = strrep(fullfile(tempFolder, ancestorName), '\', '/');

    % Extract the ancestor version from main branch
    gitCommand = sprintf('git --no-pager show origin/main:%s > %s', ...
                         fileName, ancestor);
    [status, msg] = system(gitCommand);

    if status ~= 0
        fprintf('No ancestor found for %s (new file): %s\n', fileName, msg);
        ancestor = [];
    end
end

%   Copyright 2024-2026 The MathWorks, Inc.