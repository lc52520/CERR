function dataS = populate_planC_scan_field(fieldname, dcmdir_PATIENT_STUDY_SERIES, type, seriesNum, optS)
%"populate_planC_scan_field"
%   Given the name of a child field to planC{indexS.scan}, populates that
%   field based on the data contained in the dcmdir.PATIENT.STUDY.SERIES
%   structure passed in.  Type defines the type of series passed in.
%
%JRA 06/15/06
%YWU Modified 03/01/08
%NAV 07/19/16 updated to dcm4che3
%       replaced dcm2ml_Element with getTagValue
%AI  added transferSyntaxUID for compressed images 02/02/17
%
%Usage:
%   dataS = populate_planC_scan_field(fieldname, dcmdir_PATIENT_STUDY_SERIES);
%
% Copyright 2010, Joseph O. Deasy, on behalf of the CERR development team.
%
% This file is part of The Computational Environment for Radiotherapy Research (CERR).
%
% CERR development has been led by:  Aditya Apte, Divya Khullar, James Alaly, and Joseph O. Deasy.
%
% CERR has been financially supported by the US National Institutes of Health under multiple grants.
%
% CERR is distributed under the terms of the Lesser GNU Public License.
%
%     This version of CERR is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
%
% CERR is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
% without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
% See the GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with CERR.  If not, see <http://www.gnu.org/licenses/>.

%For easier handling.

global pPos studyC;

SERIES = dcmdir_PATIENT_STUDY_SERIES;

%Default value for undefined fields.
dataS = '';

% Tolerance to determine oblique scan (think about passing it as a
% parameter in future)
obliqTol = 1e-3;

switch fieldname
    case 'scanArray'
        %dataS   = uint16([]);
        zValues = [];
        
        %Determine number of images
        nImages = length(SERIES.Data);
        %nImages = length(SERIES);
        
        multiFrameFlag = 'No';
        
        if nImages == 1
            IMAGE   = SERIES.Data;
            [imgobj, ~]  = scanfile_mldcm(IMAGE.file);
            numMultiFrameImages = getTagValue(imgobj, '00280008');
            if numMultiFrameImages > 1
                multiFrameFlag = 'Yes';
            end
        end
        
        hWaitbar = waitbar(0,'Loading Scan Data Please wait...');
        
        switch multiFrameFlag
            
            case 'No'
                
                %Iterate over slices.
                for imageNum = 1:nImages
                    
                    IMAGE   = SERIES.Data(imageNum); % wy {} --> ()
                    [imgobj, ~]  = scanfile_mldcm(IMAGE.file);
                    
                    %Pixel Data
                    %wy sliceV = getTagValue(imgobj.get(hex2dec('7FE00010')));
                    %sliceV = imgobj.getInts(org.dcm4che2.data.Tag.PixelData);

                    transferSyntaxUID = getTagValue(imgobj,'00020010');
                    %sliceV =
                    %dcm2ml_Element(imgobj.get(hex2dec('7FE00010')),transferSyntaxUID);
                    % AI
                    sliceV = getTagValue(imgobj, '7FE00010'); % NAV
                    % sliceV =
                    % dcm2ml_Element(imgobj,'7FE00010',transferSyntaxUID);
                    % ====== TO DO ===== incorporate changes related to transferSyntaxUID into getTagValue
                    
                    %Rows
                    nRows  = getTagValue(imgobj, '00280010');
                    
                    %Columns
                    nCols  = getTagValue(imgobj ,'00280011');
                    
                    %Image Position (Patient)
                    imgpos = getTagValue(imgobj, '00200032');
                    
                    %Pixel Representation commented by wy
                    pixRep = getTagValue(imgobj, '00280103');
                    
                    %Bits Allocated
                    bitsAllocated = getTagValue(imgobj, '00280100');
                    
                    if bitsAllocated > 32
                        error('Maximum 32 bits per scan pixel are supported')
                    end
                    
                    switch pixRep
                        case 0
                            if bitsAllocated == 16 || bitsAllocated == 32
                                if strcmpi(class(sliceV),'int32')
                                    if bitsAllocated == 16
                                        sliceV = typecast(sliceV,'uint16');
                                    else
                                        sliceV = typecast(sliceV,'uint32');
                                    end
                                    sliceV = sliceV(1:2:end);
                                else
                                    sliceV = typecast(sliceV,'uint16');
                                end
                            end
                        case 1
                            if bitsAllocated == 16 || bitsAllocated == 32
                                if strcmpi(class(sliceV),'int32')
                                    if bitsAllocated == 16
                                        sliceV = typecast(sliceV,'int16');
                                    else
                                        sliceV = typecast(sliceV,'int32');
                                    end
                                    sliceV = sliceV(1:2:end);
                                else
                                    sliceV = typecast(sliceV,'int16');
                                end
                            end
                        otherwise
                            sliceV = typecast(sliceV,'int16');
                            
                    end
                    %Shape the slice.
                    slice2D = reshape(sliceV, [nCols nRows]);
                    
                    % Study instance UID
                    studyUID = getTagValue(imgobj, '0020000D');

                    %Check the image orientation.
                    imgOri = getTagValue(imgobj, '00200037');
                    
                    if ~isempty(imgOri) && max(abs((imgOri(:) - [1 0 0 0 1 0]'))) < 1e-3
                        pPos = 'HFS';
                    else
                        %Check patient position
                        pPos = getTagValue(imgobj, '00185100');
                    end
                    
                    % Store the patient position associated with this studyUID
                    studyUIDc = {};
                    for i = 1:size(studyC,1)
                        studyUIDc{i} = studyC{i,1};
                    end
                    if ~any(strcmpi(studyUID,studyUIDc))
                        studyC{end+1,1} = studyUID;
                        studyC{end,2} = pPos;
                    end
                    
                    if (strcmpi(type, 'PT')) || (strcmpi(type, 'PET')) %Compute SUV for PET scans
                        %dcmobj = scanfile_mldcm(IMAGE.file);
                        %dicomHeaderS = getTagStruct(dcmobj);
                        %dicomHeaderS.PatientWeight = getTagValue(imgobj, '00101030');

                        % image units
                        imageUnits = getTagValue(imgobj, '00541001');

                        % Get calibration factor which is the Rescale slope Attribute Name in DICOM
                        %calibration_factor=dicomHeaderS.RescaleSlope;
                        rescaleSlope = getTagValue(imgobj, '00281053');

                        rescaleIntercept = getTagValue(imgobj, '00281052');
                        
                        slice2D = rescaleIntercept + single(slice2D)*rescaleSlope;
                        
%                         % factor that was used to scale this image from
%                         % counts/sec to Bq/ml using an external dose
%                         % calibrator (0054,1322)
%                         doseCalibFactor = getTagValue(imgobj, '00541322');

                        if strcmpi(imageUnits,'CNTS') % for philips scanner
                            %SUV Scale Factor
                            %suvScaleFactor = getTagValue(imgobj, '70531000');
                            %slice2D = slice2D * suvScaleFactor; % counts to SUV
                            %Activity Concentration Scale Factor
                            activityScaleFactor = getTagValue(imgobj, '70531009');
                            slice2D = slice2D * activityScaleFactor; % counts to BQ/ml
                        end
                        
                        % Moved SUV conversion to 
%                         if ~strcmpi(imageUnits,'GML')
%                                                         
%                             % Obtain SUV conversion flag from CERROptions.m
%                             pathStr = getCERRPath;
%                             optName = fullfile(pathStr,'CERROptions.json');
%                             optS    = opts4Exe(optName);
%                             if isfield(optS,'convert_PET_to_SUV') && optS.convert_PET_to_SUV
%                                 dcmobj = scanfile_mldcm(IMAGE.file);
%                                 dicomHeaderS = getTagStruct(dcmobj);
%                                 dicomHeaderS.PatientWeight = getTagValue(imgobj, '00101030');
%                                 slice2D = calc_suv(dicomHeaderS, slice2D);
%                             end
%                         end                        
                        
                    elseif ismember(type, {'MG','SM'}) % mammogram or pathology
                        imgpos = [0 0 0];
                        imgOri = zeros(6,1);

                    elseif ~strcmpi(type, 'CT')
                        %slice2D = single(slice2D);
                    
                    end
                    
                    if ischar(dataS)
                        % dataS = typecast([],class(slice2D));
                        dataS = zeros(nRows, nCols, nImages,class(slice2D));
                    end
                    
                    % Check for oblique scan
                    isOblique = 0;
                    if max(abs(abs(imgOri(:)) - [1 0 0 0 1 0]')) > obliqTol
                        isOblique = 1;
                    end
                    
                    %Store zValue for sorting, converting DICOM mm to CERR cm and
                    %inverting to match CERR's z direction.
                    zValues(imageNum) = - imgpos(3) / 10;
                    
                    %Store the slice in the 3D matrix.
                    dataS(:,:,imageNum) = slice2D';
                    
                    %if isempty(pPos)
                    %    pPos = 'HFS';
                    %end
                    
                    if ~isOblique && (imgOri(1)==-1)
                        dataS(:,:,imageNum) = flipdim(dataS(:,:,imageNum), 2);
                    end
                    if ~isOblique && (imgOri(5)==-1)
                        dataS(:,:,imageNum) = flipdim(dataS(:,:,imageNum), 1);
                    end
                    
                    if ~isOblique
                        switch upper(pPos)
                            case 'HFP'
                                dataS(:,:,imageNum) = flipdim(dataS(:,:,imageNum), 1); %Similar flip as doseArray
                                dataS(:,:,imageNum) = flipdim(dataS(:,:,imageNum), 2); % 1/3/2017
                                
                            case 'FFS'
                                dataS(:,:,imageNum) = flipdim(dataS(:,:,imageNum), 2);  % 1/3/2017
                                
                            case 'FFP'
                                dataS(:,:,imageNum) = flipdim(dataS(:,:,imageNum), 1); %Similar flip as doseArray
                        end
                    end
                    
                    clear imageobj;
                    
                    waitbar(imageNum/(nImages),hWaitbar, ['Loading scans from Series ' num2str(seriesNum) '. Please wait...']);
                end
                                
                %Reorder 3D matrix based on zValues.
                [jnk, zOrder]       = sort(zValues);
                dataS(:,:,1:end)    = dataS(:,:,zOrder);
                
            case 'Yes' % Assume Nuclear medicine image
                
                    transferSyntaxUID = getTagValue(imgobj,'00020010');
                    % sliceV =
                    % dcm2ml_Element(imgobj.get(hex2dec('7FE00010')),transferSyntaxUID);
                    % AI
                    % sliceV = getTagValue(imgobj, '7FE00010'); % NAV
                    sliceV = dcm2ml_Element(imgobj,'7FE00010',transferSyntaxUID);
                    
                    %Rows
                    nRows  = getTagValue(imgobj, '00280010');
                    
                    %Columns
                    nCols  = getTagValue(imgobj, '00280011');
                    
                    %Image Position (Patient)                   

                    %detectorInfoSequence = getTagValue(imgobj, '00540022');
                    %imgOri = detectorInfoSequence.Item_1.ImageOrientationPatient;
                    
                    %Pixel Representation commented by wy
                    pixRep = getTagValue(imgobj, '00280103');
                    
                    %Bits Allocated
                    bitsAllocated = getTagValue(imgobj, '00280100');
                    
                    if bitsAllocated > 16
                        error('Only 16 bits per scan pixel are supported')
                    end
                    
                    switch pixRep
                        case 0
                            if bitsAllocated == 16
                                if strcmpi(class(sliceV),'int32')
                                    sliceV = typecast(sliceV,'uint16');
                                    sliceV = sliceV(1:2:end);
                                else
                                    sliceV = typecast(sliceV,'uint16');
                                end
                            end
                        case 1
                            if bitsAllocated == 16
                                if strcmpi(class(sliceV),'int32')
                                    sliceV = typecast(sliceV,'int16');
                                    sliceV = sliceV(1:2:end);
                                else
                                    sliceV = typecast(sliceV,'int16');
                                end
                            end
                            
                    end
                    %Shape the slice.
                    dataS = reshape(sliceV, [nCols nRows numMultiFrameImages]);
                    dataS = permute(dataS,[2 1 3]);
                    
                    % Study instance UID
                    studyUID = dcm2ml_Element(imgobj.get(hex2dec('0020000D')));
                    
                    %Check patient position
                    pPos = getTagValue(imgobj, '00185100');
                    
                    % Get Patient Position from the associated CT/MR scan
                    % in case of NM missing the patient position.
                    modality = dcm2ml_Element(imgobj.get(hex2dec('00080060')));
                    studyUIDc = {};
                    for i = 1:size(studyC,1)
                        studyUIDc{i} = studyC{i,1};
                    end                    
                    if strcmpi(modality,'NM') && isempty(pPos)
                        studyIndex = strcmpi(studyUID,studyUIDc);
                        pPos = studyC{studyIndex,2};
                    end
                    
                    % Store the patient position associated with this studyUID
                    if ~any(strcmpi(studyUID,studyUIDc))
                        studyC{end+1,1} = studyUID;
                        studyC{end,2} = pPos;
                    end                    
                    
                    imgpos = dcm2ml_Element(imgobj.get(hex2dec('00200032')));
                    imgOri = dcm2ml_Element(imgobj.get(hex2dec('00200037')));
                    if isempty(imgpos) && strcmpi(modality,'NM')
                        % Multiframe NM image.
                        detectorInfoSequence = dcm2ml_Element(imgobj.get(hex2dec('00540022')));
                        imgpos = detectorInfoSequence.Item_1.ImagePositionPatient;
                        imgOri = detectorInfoSequence.Item_1.ImageOrientationPatient;                        
                    end
                          
                    % Check for oblique scan
                    isOblique = 0;
                    if isempty(imgOri) || max(abs(abs(imgOri(:)) - [1 0 0 0 1 0]')) > obliqTol
                        isOblique = 1;
                    end
                    
                    if ~isOblique && (imgOri(1)==-1)
                        dataS = flipdim(dataS, 2);
                    end
                    if ~isOblique && (imgOri(5)==-1)
                        dataS = flipdim(dataS, 1);
                    end
                    
                    if ~isOblique && (isequal(pPos,'HFP') || isequal(pPos,'FFP'))
                        dataS = flipdim(dataS, 1); %Similar flip as doseArray
                    end
                    
                    if ~isOblique && (isequal(pPos,'FFP') || isequal(pPos,'FFS'))
                        dataS = flipdim(dataS, 3); %Similar flip as doseArray
                    end
                    clear imageobj;                    
                
        end
        
        close(hWaitbar);
        pause(1);
        
        
    case 'scanType'
        
    case 'scanInfo'
        %Determine number of images
        nImages = length(SERIES.Data);
        
        multiFrameFlag = 'No';
        if nImages == 1
            IMAGE   = SERIES.Data;
            imgobj  = scanfile_mldcm(IMAGE.file);
            numMultiFrameImages = getTagValue(imgobj, '00280008');
            if numMultiFrameImages > 1
                multiFrameFlag = 'Yes';
            end
        end        
        
        %Get scanInfo field names.
        scanInfoInitS = initializeScanInfo;
        names = fields(scanInfoInitS);
        
        zValues = [];
        
        hWaitbar = waitbar(0,'Loading Scan Info Please wait...');
        
        switch multiFrameFlag
            
            case 'No'
                
                %Iterate over slices.
                for imageNum = 1:nImages
                    
                    IMAGE   = SERIES.Data(imageNum);  % wy {} --> ()
                    imgobj  = scanfile_mldcm(IMAGE.file);
                    
                    %Image Position (Patient)
                    imgpos = getTagValue(imgobj, '00200032');
                    
                    % Image Orientation                    
                    imgOri = getTagValue(imgobj,'00200037');
                    
                    if ismember(type,{'MG','SM'}) % mammogram or pathology
                        imgpos = [0 0 0];
                        imgOri = zeros(6,1);
                    end
                    
                    % Check for oblique scan
                    isOblique = 0;
                    if max(abs(abs(imgOri(:)) - [1 0 0 0 1 0]')) > obliqTol
                        isOblique = 1;
                    end
                    
                    %Store zValue for sorting, converting DICOM mm to CERR cm and
                    %inverting to match CERR's z direction.
                    zValues(imageNum) = - imgpos(3) / 10;
                    
                    for i = 1:length(names)
                        dataS(imageNum).(names{i}) = ...
                            populate_planC_scan_scanInfo_field(names{i}, IMAGE, imgobj, optS);
                    end
                    
                    clear imageobj;
                    
                    waitbar(imageNum/(nImages),hWaitbar, ['Loading scans Info. ' 'Please wait...']);
                end                
                
                %Reorder scanInfo elements based on zValues.
                [jnk, zOrder]   = sort(zValues);
                dataS(1:end)    = dataS(zOrder);
                
            case 'Yes' % Assume Nuclear Medicine Image
                sliceSpacing = getTagValue(imgobj, '00180088');
                %zValues = 0:sliceThickness:sliceThickness*double(numMultiFrameImages-1);
                modality = dcm2ml_Element(imgobj.get(hex2dec('00080060')));
                %detectorInfoSequence = getTagValue(imgobj, '00540022');                                
                %imgpos = detectorInfoSequence.Item_1.ImagePositionPatient;
                %imgpos = dcm2ml_Element(imgobj.get(hex2dec('00200032')));
                imgpos = getTagValue(imgobj, '00200032');
                %imgOri = dcm2ml_Element(imgobj.get(hex2dec('00200037')));
                imgOri = getTagValue(imgobj, '00200037');
                if isempty(imgpos) && strcmpi(modality,'NM')
                    % Multiframe NM image.
                    %detectorInfoSequence = dcm2ml_Element(imgobj.get(hex2dec('00540022')));
                    detectorInfoSequence = getTagValue(imgobj, '00540022'); 
                    imgpos = detectorInfoSequence.Item_1.ImagePositionPatient;
                    imgOri = detectorInfoSequence.Item_1.ImageOrientationPatient;
                end
                
                % Check for oblique scan
                isOblique = 0;
                if isempty(imgOri) || max(abs(abs(imgOri(:)) - [1 0 0 0 1 0]')) > 1e-2
                    isOblique = 1;
                end
                
                if strcmpi(modality,'MG')
                    imgpos = [0 0 0];
                    xray3dAcqSeq = dcm2ml_Element(imgobj.get(hex2dec('00189507')));
                    bodyPartThickness = xray3dAcqSeq.Item_1.BodyPartThickness;
                    sliceSpacing = bodyPartThickness/double(numMultiFrameImages);
                end                
                
                if strcmpi(modality,'SM')
                    imgpos = [0 0 0];
                    sharedFrameFuncGrpSeq = dcm2ml_Element(imgobj.get(hex2dec('52009229')));
                    sliceSpacing = sharedFrameFuncGrpSeq.Item_1.PixelMeasuresSequence.Item_1.SliceThickness;                    
                end
                
                zValuesV = imgpos(3):sliceSpacing:imgpos(3)+sliceSpacing*double(numMultiFrameImages-1);
                if sliceSpacing < 0 % http://dicom.nema.org/medical/dicom/current/output/chtml/part03/sect_C.8.4.15.html
                    zValuesV = fliplr(zValuesV);
                end
                if ~isOblique && (isequal(pPos,'FFP') || isequal(pPos,'FFS'))
                    zValuesV = fliplr(zValuesV);
                end
                for i = 1:length(names)
                    dataS(1).(names{i}) = ...
                        populate_planC_scan_scanInfo_field(names{i}, IMAGE, imgobj, optS);
                end
                for imageNum = 1:numMultiFrameImages
                    dataS(imageNum) = dataS(1);
                    if ~isOblique
                        dataS(imageNum).zValue = -zValuesV(imageNum)/10;
                    else
                        dataS(imageNum).zValue = zValuesV(imageNum)/10;
                    end
                end
                
        end
        
        close(hWaitbar);
        
        
    case 'uniformScanInfo'
        %Implementation is unnecessary.
    case 'scanArraySuperior'
        %Implementation is unnecessary.
    case 'scanArrayInferior'
        %Implementation is unnecessary.
    case 'thumbnails'
        %Implementation is unnecessary.
    case 'transM'
        %Implementation is unnecessary.
    case 'scanUID'
        %Series Instance UID
        dataS = getTagValue(SERIES.info, '0020000E');
        
        %wy, use the frame of reference UID to associate dose to scan.
        %IMAGE   = SERIES.Data(1); % wy {} --> ()
        %imgobj  = scanfile_mldcm(IMAGE.file);
        %dataS = char(imgobj.getString(org.dcm4che2.data.Tag.FrameofReferenceUID));
        %dataS = getTagValue(imgobj.get(hex2dec('00080018')));
        %dataS = getTagValue(imgobj.get(hex2dec('0020000E')));
        dataS = ['CT.',dataS];
        
    otherwise
        %         warning(['DICOM Import has no methods defined for import into the planC{indexS.scan}.' fieldname ' field, leaving empty.']);
end