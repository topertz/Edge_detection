function block_processing_large_images
    % === Create GUI Figure ===
    fig = figure('Name','Edge Detection GUI',...
                 'NumberTitle','off',...
                 'Position',[500 300 300 200],...
                 'Resize','off');

    uicontrol('Style','pushbutton',...
              'String','Image Edge Detection',...
              'FontSize',12,...
              'Position',[50 120 200 50],...
              'Callback',@runImageCode);

    uicontrol('Style','pushbutton',...
              'String','Video Edge Detection',...
              'FontSize',12,...
              'Position',[50 40 200 50],...
              'Callback',@runVideoCode);
end


%% ------------------------------------------------------------------------
%% --- IMAGE EDGE DETECTION (BUTTON 1) -----------------------------------
%% ------------------------------------------------------------------------
function runImageCode(~,~)

    %% Pick an image
    [filename, pathname] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif',...
                                      'Képfájlok (*.png, *.jpg, *.jpeg, *.bmp, *.tif)'});
    if isequal(filename,0)
        disp('No file selected.');
        return;
    end
    file_name = fullfile(pathname, filename);
    I = imread(file_name);

    %% Convert to grayscale for edge detection
    if size(I,3) == 3
        Igray = rgb2gray(I);
    else
        Igray = I;
    end

    %% Parameters
    thresh = 0.09;
    block_size = [100 100];
    border_size = [10 10];

    %% Block-wise edge detection functions
    canny     = blockproc(Igray, block_size, @(b) edge(b.data,"canny",thresh), "BorderSize",border_size);
    sobel     = blockproc(Igray, block_size, @(b) edge(b.data,"sobel"),         "BorderSize",border_size);
    roberts   = blockproc(Igray, block_size, @(b) edge(b.data,"roberts"),       "BorderSize",border_size);
    prewitt   = blockproc(Igray, block_size, @(b) edge(b.data,"prewitt"),       "BorderSize",border_size);
    laplacian = blockproc(Igray, block_size, @(b) edge(b.data,"log"),           "BorderSize",border_size);


    %% --- Display results ---
    figure;
    subplot(2,3,1), imshow(I), title("Original");
    subplot(2,3,2), imshow(canny), title("Canny");
    subplot(2,3,3), imshow(sobel), title("Sobel");
    subplot(2,3,4), imshow(roberts), title("Roberts");
    subplot(2,3,5), imshow(prewitt), title("Prewitt");
    subplot(2,3,6), imshow(laplacian), title("Laplacian");

    %% Optional objective metric comparison
    try
        [psnr_canny,    ssim_canny]    = compare_metrics(I, canny);
        [psnr_sobel,    ssim_sobel]    = compare_metrics(I, sobel);
        [psnr_roberts,  ssim_roberts]  = compare_metrics(I, roberts);
        [psnr_prewitt,  ssim_prewitt]  = compare_metrics(I, prewitt);
        [psnr_laplacian,ssim_laplacian]= compare_metrics(I, laplacian);

        fprintf('PSNR és SSIM értékek:\n');
        fprintf('Canny: PSNR = %.2f, SSIM = %.3f\n', psnr_canny, ssim_canny);
        fprintf('Sobel: PSNR = %.2f, SSIM = %.3f\n', psnr_sobel, ssim_sobel);
        fprintf('Roberts: PSNR = %.2f, SSIM = %.3f\n', psnr_roberts, ssim_roberts);
        fprintf('Prewitt: PSNR = %.2f, SSIM = %.3f\n', psnr_prewitt, ssim_prewitt);
        fprintf('Laplacian: PSNR = %.2f, SSIM = %.3f\n', psnr_laplacian, ssim_laplacian);
    catch
        warning('compare_metrics function not found or error occurred.');
    end

end



%% ------------------------------------------------------------------------
%% --- VIDEO EDGE DETECTION (BUTTON 2) -----------------------------------
%% ------------------------------------------------------------------------
function runVideoCode(~,~)

    %% Pick video file
    [file, path] = uigetfile({'*.mp4;*.avi;*.mov','Video files'});
    if isequal(file,0)
        disp('No video selected.');
        return;
    end
    video_file = fullfile(path, file);

    v = VideoReader(video_file);

    %% Parameters
    thresh = 0.09;
    block_size  = [50 50];
    border_size = [10 10];

    %% Edge functions (same as image processing)
    edgeCanny     = @(b) edge(b.data,"canny",thresh);
    edgeSobel     = @(b) edge(b.data,"sobel");
    edgeRoberts   = @(b) edge(b.data,"roberts");
    edgePrewitt   = @(b) edge(b.data,"prewitt");
    edgeLaplacian = @(b) edge(b.data,"log");

    %% Create output videos
    vw_canny     = VideoWriter('video_canny.avi',     'Uncompressed AVI');
    vw_sobel     = VideoWriter('video_sobel.avi',     'Uncompressed AVI');
    vw_roberts   = VideoWriter('video_roberts.avi',   'Uncompressed AVI');
    vw_prewitt   = VideoWriter('video_prewitt.avi',   'Uncompressed AVI');
    vw_laplacian = VideoWriter('video_laplacian.avi', 'Uncompressed AVI');
    
    vw_canny.FrameRate     = v.FrameRate;
    vw_sobel.FrameRate     = v.FrameRate;
    vw_roberts.FrameRate   = v.FrameRate;
    vw_prewitt.FrameRate   = v.FrameRate;
    vw_laplacian.FrameRate = v.FrameRate;

    open(vw_canny);
    open(vw_sobel);
    open(vw_roberts);
    open(vw_prewitt);
    open(vw_laplacian);

    %% Process video
    while hasFrame(v)
        frame = readFrame(v);

        % Convert to grayscale
        if size(frame,3) == 3
            gray = rgb2gray(frame);
        else
            gray = frame;
        end

        % Block-wise edge detection
        canny     = blockproc(gray, block_size, edgeCanny,     "BorderSize",border_size);
        sobel     = blockproc(gray, block_size, edgeSobel,     "BorderSize",border_size);
        roberts   = blockproc(gray, block_size, edgeRoberts,   "BorderSize",border_size);
        prewitt   = blockproc(gray, block_size, edgePrewitt,   "BorderSize",border_size);
        laplacian = blockproc(gray, block_size, edgeLaplacian, "BorderSize",border_size);

        % Write frames
        frame_out = repmat(im2uint8(canny), [1 1 3]);
        frame_out = makeEvenSize(frame_out);
        writeVideo(vw_canny, frame_out);
        frame_out = repmat(im2uint8(sobel), [1 1 3]);
        frame_out = makeEvenSize(frame_out);
        writeVideo(vw_sobel, frame_out);
        frame_out = repmat(im2uint8(roberts), [1 1 3]);
        frame_out = makeEvenSize(frame_out);
        writeVideo(vw_roberts, frame_out);
        frame_out = repmat(im2uint8(prewitt), [1 1 3]);
        frame_out = makeEvenSize(frame_out);
        writeVideo(vw_prewitt, frame_out);
        frame_out = repmat(im2uint8(laplacian), [1 1 3]);
        frame_out = makeEvenSize(frame_out);
        writeVideo(vw_laplacian, frame_out);
    end

    %% Close videos
    close(vw_canny);
    close(vw_sobel);
    close(vw_roberts);
    close(vw_prewitt);
    close(vw_laplacian);

    disp("All edge-detected videos saved:");
    disp(" - video_canny.avi");
    disp(" - video_sobel.avi");
    disp(" - video_roberts.avi");
    disp(" - video_prewitt.avi");
    disp(" - video_laplacian.avi");
end

function out = makeEvenSize(img)
    h = size(img,1);
    w = size(img,2);

    if mod(h,2) ~= 0
        img(end,:) = [];
    end
    if mod(w,2) ~= 0
        img(:,end) = [];
    end

    out = img;
end

%% compare metrics
function [psnr_val, ssim_val] = compare_metrics(original, processed)

    % Convert original to grayscale if needed
    if size(original,3) == 3
        original = rgb2gray(original);
    end

    % Make both images double
    original  = im2double(original);
    processed = im2double(processed);

    % Ensure sizes match
    if ~isequal(size(original), size(processed))
        processed = imresize(processed, size(original));
    end

    % Compute PSNR + SSIM
    psnr_val = psnr(processed, original);
    ssim_val = ssim(processed, original);
end
