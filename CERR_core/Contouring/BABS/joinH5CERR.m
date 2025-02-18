function success  = joinH5CERR(segResultCERRPath, cerrPath, outputH5Path, algorithm)
% Usage: res = joinH5CERR(segResultCERRPath, cerrPath, outputH5Path, configFilePath)
%
% This function merges the segmentations from the respective algorithm back
% into the original CERR file
%
% RKP, 3/21/2019
%
% INPUTS:
%   cerrPath          : Path to the original CERR file to be segmented
%   segResultCERRPath : Path to write CERR RTSTRUCT for resulting segmentation.
%   outputH5Path      : Path to the segmented structures saved in h5 file format
%   configFilePath    : Path to the config file of the specific algorithm being
%                       used for segmentation

configFilePath = fullfile(getCERRPath,'Contouring','models', 'ModelConfigurationFiles', [algorithm, '_config','.json']);

% check if any pre-processing is required
%configFilePath = fullfile(getCERRPath,'Contouring','models','heart','heart.json');
userInS = jsondecode(fileread(configFilePath));
preProcMethod = userInS.preproc.method;
preProcOptC = userInS.preproc.params;

%Get H5 files
H5Files = dir(fullfile(outputH5Path,'*.h5'));

if ispc
        slashType = '\';
    else
        slashType = '/';
end

%walk through the h5 files in the dir
for file = H5Files
    
    %get result mask 
    H5.open();     
    filename = strcat(file.folder,slashType, file.name)
    file_id = H5F.open(filename);
    dset_id_data = H5D.open(file_id,'mask');
    data = H5D.read(dset_id_data);

    %load original planC
    planCfiles = dir(fullfile(cerrPath,'*.mat'));
    planCfilename = fullfile(planCfiles.folder, planCfiles.name);
    planC = load(planCfilename);
    planC = planC.planC;
    indexS = planC{end};
    
    %flip and permute mask to match current orientation
    OriginalMaskM = data;
    permutedMask = permute(OriginalMaskM, [3 2 1]);
    flippedMask = permutedMask; 
    scanNum = 1;             
    isUniform = 1;   
           
end
    
    %read json file to get segmented structure names
    filetext = fileread(configFilePath);    
    res = jsondecode(filetext);          
        
    %if any pre-processing was done, pad mask to get original size    
    if ~isempty(preProcMethod)         
        count = res.loadStructures(1).value;
        for i = 1 : length(res.loadStructures)             
            tmpM1 = flippedMask == count;
            mask3M = padMask(planC,scanNum,tmpM1,preProcMethod,preProcOptC);
            tmpM2 = mask3M == 1;
            planC = maskToCERRStructure(tmpM2, isUniform, scanNum, res.loadStructures(i).structureName, planC);
            count = count+1;
        end
    else
        for i = 1 : length(res.loadStructures)         
            mask3M = flippedMask == i;
            planC = maskToCERRStructure(mask3M, isUniform, scanNum, res.loadStructures(i).structureName, planC);
        end
    end
    
    %save final plan
    finalPlanCfilename = fullfile(segResultCERRPath, strrep(strrep(file.name, 'MASK_', ''),'.h5', '.mat'))
    optS = [];
    saveflag = 'passed';
    save_planC(planC,optS,saveflag,finalPlanCfilename);
  
success = 1;    
end  

    
    
    