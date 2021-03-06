function [ pyramid_all ] = CompilePyramid( imageFileList, dataBaseDir, textonSuffix, dictionarySize, pyramidLevels, params )
%function [ pyramid_all ] = CompilePyramid( imageFileList, dataBaseDir, textonSuffix, dictionarySize, pyramidLevels, canSkip )
%
% Generate the pyramid from the texton lablels
%
% For each image the texton labels are loaded. Then the histograms are
% calculated for the finest level. The rest of the pyramid levels are
% generated by combining the histograms of the higher level.
%
% imageFileList: cell of file paths
% dataBaseDir: the base directory for the data files that are generated
%  by the algorithm. If this dir is the same as imageBaseDir the files
%  will be generated in the same location as the image file
% textonSuffix: this is the suffix appended to the image file name to
%  denote the data file that contains the textons indices and coordinates. 
%  Its default value is '_texton_ind_%d.mat' where %d is the dictionary
%  size.
% dictionarySize: size of descriptor dictionary (200 has been found to be
%  a good size)
% pyramidLevels: number of levels of the pyramid to build
% canSkip: if true the calculation will be skipped if the appropriate data 
%  file is found in dataBaseDir. This is very useful if you just want to
%  update some of the data or if you've added new images.

fprintf('Building Spatial Pyramid\n\n');

%% parameters

if(nargin<4)
    dictionarySize = 200
end

if(nargin<5)
    pyramidLevels = 4
end

if(nargin<6)
    canSkip = 0
end

binsHigh = 2^(pyramidLevels-1);

featureLength = 0;
for i=0:pyramidLevels-1;
   featureLength = featureLength + (2^(2*i))  * dictionarySize;
end

pyramid_all = zeros(size(imageFileList,1), featureLength);
pyramid = zeros(1,featureLength);

for f = 1:size(imageFileList,1)


    %% load image
    imageFName = imageFileList{f};
    [dirN base] = fileparts(imageFName);
    baseFName = fullfile(dirN, base);
    
    outFName = fullfile(dataBaseDir, sprintf('%s_pyramid_%d_%d_%d_%d.mat', baseFName, dictionarySize, pyramidLevels, params.numNeighbors, params.max_pooling));
    if(size(dir(outFName),1)~=0 && params.can_skip && params.can_skip_compilepyramid)
        fprintf('Skipping %s\n', imageFName);
        load(outFName, 'pyramid');
        pyramid_all(f,:) = pyramid;
        if (params.sum_norm)
            pyramid = pyramid/sum(pyramid);
        else
            pyramid = pyramid/norm(pyramid);
        end
        continue;
    end
    
    %% load texton indices
    in_fname = fullfile(dataBaseDir, sprintf('%s%s', baseFName, textonSuffix));
    load(in_fname, 'texton_ind');
    
    %% get width and height of input image
    wid = texton_ind.wid;
    hgt = texton_ind.hgt;

    fprintf('Loaded %s: wid %d, hgt %d\n', ...
             imageFName, wid, hgt);

    %% compute histogram at the finest level
    pyramid_cell = cell(pyramidLevels,1);
    pyramid_cell{1} = zeros(binsHigh, binsHigh, dictionarySize);

    for i=1:binsHigh
        for j=1:binsHigh

            % find the coordinates of the current bin
            x_lo = floor(wid/binsHigh * (i-1));
            x_hi = floor(wid/binsHigh * i);
            y_lo = floor(hgt/binsHigh * (j-1));
            y_hi = floor(hgt/binsHigh * j);
            
            texton_patch = texton_ind.data( (texton_ind.x > x_lo) & (texton_ind.x <= x_hi) & ...
                                            (texton_ind.y > y_lo) & (texton_ind.y <= y_hi), :);
            texton_indices = texton_ind.indices( (texton_ind.x > x_lo) & (texton_ind.x <= x_hi) & ...
                                            (texton_ind.y > y_lo) & (texton_ind.y <= y_hi),:);
            % make histogram of features in bin
            %this is sum pooling
            
            for texton=1:size(texton_indices,1),
                if (params.max_pooling==1)
                   pyramid_cell{1}(i,j,texton_indices(texton,:)) = max(pyramid_cell{1}(i,j,texton_indices(texton,:)),permute(texton_patch(texton,:), [3 1 2])); 
                else
                    pyramid_cell{1}(i,j,texton_indices(texton,:))=...
                        pyramid_cell{1}(i,j,texton_indices(texton,:)) +texton_patch(texton,:);
                end
            end
            pyramid_cell{1}(i,j,:) = pyramid_cell{1}(i,j,:)./length(texton_ind.data);
            %pyramid_cell{1}(i,j,:) = hist(texton_indices, 1:dictionarySize)./length(texton_ind.data);
        end
    end

    %% compute histograms at the coarser levels
    num_bins = binsHigh/2;
    for l = 2:pyramidLevels
        pyramid_cell{l} = zeros(num_bins, num_bins, dictionarySize);
        for i=1:num_bins
            for j=1:num_bins
                if (params.max_pooling==1)
                    pyramid_cell{l}(i,j,:) = max(max(max(...
                    pyramid_cell{l-1}(2*i-1,2*j-1,:),pyramid_cell{l-1}(2*i,2*j-1,:)), ...
                    pyramid_cell{l-1}(2*i-1,2*j,:)), pyramid_cell{l-1}(2*i,2*j,:));
                else
                    pyramid_cell{l}(i,j,:) = ...
                    pyramid_cell{l-1}(2*i-1,2*j-1,:) + pyramid_cell{l-1}(2*i,2*j-1,:) + ...
                    pyramid_cell{l-1}(2*i-1,2*j,:) + pyramid_cell{l-1}(2*i,2*j,:);
                end
            end
        end
        num_bins = num_bins/2;
    end

    %% stack all the histograms with appropriate weights
    if (params.max_pooling)
        curEnd = 0;
        for l = 1:pyramidLevels-1
            pyramid(curEnd + (1:numel(pyramid_cell{l}))) = pyramid_cell{l}(:)';
            curEnd = curEnd + numel(pyramid_cell{l});
        end
        pyramid((curEnd+1):end) = pyramid_cell{pyramidLevels}(:)';
    else
         curEnd = 0;
        for l = 1:pyramidLevels-1
            pyramid(curEnd + (1:numel(pyramid_cell{l}))) = pyramid_cell{l}(:)' .* 2^(-l);
            curEnd = curEnd + numel(pyramid_cell{l});
        end
        pyramid((curEnd+1):end) = pyramid_cell{pyramidLevels}(:)' .* 2^(1-pyramidLevels);
    end

    %%Normalize
    if (params.sum_norm)
        pyramid = pyramid/sum(pyramid);
    else
        pyramid = pyramid/norm(pyramid);
    end
    
    % save pyramid
    save(outFName, 'pyramid');

    pyramid_all(f,:) = pyramid;

end % f

outFName = fullfile(dataBaseDir, sprintf('pyramids_all_%d_%d_%d_%d.mat', dictionarySize, pyramidLevels, params.numNeighbors, params.max_pooling));
save(outFName, 'pyramid_all');


end
