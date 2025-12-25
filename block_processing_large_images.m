function block_processing_large_images
    % === Create GUI Figure ===
    figure('Name','Edge Detection GUI',...
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
    
    %% --- NEW: Method selection window ---
    d = dialog('Position', [300 300 280 220], 'Name', 'Válassz metódust');
    uicontrol('Parent', d, 'Style', 'text', 'Position', [20 180 160 30], ...
              'String', 'Válassz éldetektálást:', 'FontSize', 10);
    
    selectedMethod = '';
    methods = {'Canny','Sobel','Roberts','Prewitt','Laplacian'};
    
    for i = 1:length(methods)
        uicontrol('Parent', d, 'Style', 'pushbutton', ...
            'Position', [40 170-i*30 120 25], ...
            'String', methods{i}, ...
            'Callback', @(src, event) assignAndClose(methods{i}));
    end
    
    function assignAndClose(m)
        selectedMethod = m;
        delete(d);
    end
    
    uiwait(d); 
    if isempty(selectedMethod), return; end 

    %% Image loading and grayscale conversion
    file_name = fullfile(pathname, filename);
    I = imread(file_name);
    if size(I,3) == 3
        Igray = rgb2gray(I);
    else
        Igray = I;
    end

    %% Parameters
    thresh = 0.09;
    block_size = [100 100];
    border_size = [10 10];

    %% Selecting an edge detection function
    switch selectedMethod
        case 'Canny'
            edgeFun = @(b) edge(b.data,"canny",thresh);
        case 'Sobel'
            edgeFun = @(b) edge(b.data,"sobel");
        case 'Roberts'
            edgeFun = @(b) edge(b.data,"roberts");
        case 'Prewitt'
            edgeFun = @(b) edge(b.data,"prewitt");
        case 'Laplacian'
            edgeFun = @(b) edge(b.data,"log");
    end

    %% Processing with blockproc (runs only the selected one)
    processedImg = blockproc(Igray, block_size, edgeFun, "BorderSize", border_size);

    %% --- Show result ---
    figure('Name', ['Edge Detection Result - ' selectedMethod]);
    subplot(1,2,1), imshow(I), title("Original");
    subplot(1,2,2), imshow(processedImg), title(selectedMethod);

    %% Metric calculation
    try
        [psnr_val, ssim_val] = compare_metrics(I, processedImg);
        fprintf('\nEredmények (%s):\n', selectedMethod);
        fprintf('PSNR = %.2f\nSSIM = %.3f\n', psnr_val, ssim_val);
    catch
        warning('Hiba a metrikák számításakor.');
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

    %% Choose edge detection method (Egyedi ablak listdlg helyett)
    d = dialog('Position', [300 300 280 220], 'Name', 'Válassz metódust');
    uicontrol('Parent', d, 'Style', 'text', 'Position', [20 180 160 30], ...
              'String', 'Válassz éldetektálást:', 'FontSize', 10);
    
    selectedMethod = '';
    methods = {'Canny','Sobel','Roberts','Prewitt','Laplacian'};
    
    % Creating buttons
    for i = 1:length(methods)
        uicontrol('Parent', d, 'Style', 'pushbutton', ...
            'Position', [40 170-i*30 120 25], ...
            'String', methods{i}, ...
            'Callback', @(src, event) assignAndClose(methods{i}));
    end

    % Helper function for selection
    function assignAndClose(m)
        selectedMethod = m;
        delete(d);
    end

    uiwait(d); % Wait until the window closes
    if isempty(selectedMethod), return; end % If only you had closed the window

    %% Parameters
    thresh = 0.09;
    block_size  = [50 50];
    border_size = [10 10];

    %% Select edge function
    switch selectedMethod
        case 'Canny'
            edgeFun = @(b) edge(b.data,"canny",thresh);
        case 'Sobel'
            edgeFun = @(b) edge(b.data,"sobel");
        case 'Roberts'
            edgeFun = @(b) edge(b.data,"roberts");
        case 'Prewitt'
            edgeFun = @(b) edge(b.data,"prewitt");
        case 'Laplacian'
            edgeFun = @(b) edge(b.data,"log");
    end

    %% Create output video
    outputName = ['video_' lower(selectedMethod) '.avi'];
    vw = VideoWriter(outputName, 'Uncompressed AVI');
    vw.FrameRate = v.FrameRate;
    open(vw);

    %% Create display figure
    figure('Name',['Video Edge Detection - ' selectedMethod], ...
                      'NumberTitle','off');

    firstFrame = readFrame(v);
    if size(firstFrame,3) == 3
        gray = rgb2gray(firstFrame);
    else
        gray = firstFrame;
    end

    edges = blockproc(gray, block_size, edgeFun, "BorderSize", border_size);
    frame_out = repmat(im2uint8(edges), [1 1 3]);
    frame_out = makeEvenSize(frame_out);

    hAx  = gca;                      % axes handle
    hImg = imshow(frame_out);
    title(hAx, selectedMethod, 'FontSize', 14, 'FontWeight','bold');
    drawnow;

    %% Write first frame
    writeVideo(vw, frame_out);

    %% Process remaining frames
    while hasFrame(v) && ishandle(hImg)

        frame = readFrame(v);

        % Convert to grayscale
        if size(frame,3) == 3
            gray = rgb2gray(frame);
        else
            gray = frame;
        end

        % Block-wise edge detection
        edges = blockproc(gray, block_size, edgeFun, ...
                          "BorderSize", border_size);

        frame_out = repmat(im2uint8(edges), [1 1 3]);
        frame_out = makeEvenSize(frame_out);

        % Display in GUI
        set(hImg, 'CData', frame_out);
        title(hAx, selectedMethod, 'FontSize', 14, 'FontWeight','bold');
        drawnow;

        % Save frame
        writeVideo(vw, frame_out);
    end

    %% Close video
    close(vw);

    disp("Edge-detected video saved:");
    disp(outputName);

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
