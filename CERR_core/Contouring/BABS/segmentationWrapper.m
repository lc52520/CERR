function success = segmentationWrapper(cerrPath,segResultCERRPath,fullSessionPath, containerPath, algorithm)
% function success =heart(cerrPath,segResultCERRPath,fullSessionPath,deepLabContainerPath)
%
% This function serves as a wrapper for the all segmentation models
%
% INPUT: 
% cerrPath - path to the original CERR file to be segmented
% segResultCERRPath - path to write CERR RTSTRUCT for resulting segmentation.
% fullSessionPath - path to write temporary segmentation metadata.
% deepLabContainerPath - path to the MR Prostate DeepLab V3+ container on the
%algorithm - name of the algorithm to run
% system
% 
%
%
% RKP, 5/21/2019

containerPath
algorithm

%build config file path from algorithm
configFilePath = fullfile(getCERRPath,'Contouring','models', 'ModelConfigurationFiles', [algorithm, '_config','.json']);
        
% check if any pre-processing is required  
%configFilePath = fullfile(getCERRPath,'Contouring','models','heart','heart.json');
userInS = jsondecode(fileread(configFilePath)); 
preProcMethod = userInS.preproc.method;
preProcOptC = userInS.preproc.params;      
        
% convert scan to H5 format
cerrToH5(cerrPath, fullSessionPath, preProcMethod, preProcOptC);

% % create subdir within fullSessionPath for output h5 files
outputH5Path = fullfile(fullSessionPath,'outputH5');
mkdir(outputH5Path);

bindingDir = ':/scratch'
bindPath = strcat(fullSessionPath,bindingDir)
    
% Execute the container
command = sprintf('singularity run --app %s --nv --bind  %s %s %s', algorithm, bindPath, containerPath, fullSessionPath)
status = system(command)


% join segmented mask with planC
success = joinH5CERR(segResultCERRPath,cerrPath,outputH5Path,algorithm);
