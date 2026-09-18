clear; close all; clc;

% ---- PARAMETERS ----
BT = 0.5;                         % Bandwidth-symbol product (adjust for BLE)
span_values = [3 4 6 8];         % Span (in symbols)
sps_values  = [4 8 16 32];        % Samples per symbol (oversampling)

% ---- STORAGE STRUCT ----
results = struct();

for si = 1:length(span_values)
    for pi = 1:length(sps_values)
        
        span = span_values(si);
        sps  = sps_values(pi);

        % -------- Create Gaussian Filter --------
        h = gaussdesign(BT, span, sps);

        % -------- Impulse Response --------
        L = length(h);
        t = ((0:L-1) - (L-1)/2) / sps;    % centered, in symbol units

        % -------- Frequency Response --------
        [Hf, f] = freqz(h, 1, 2048, 'whole');
        Hmag = abs(Hf);
        f_norm = f / (2*pi) / sps;        % normalize to symbol rate

        % -------- Store results --------
        results(si, pi).span = span;
        results(si, pi).sps = sps;
        results(si, pi).h = h;
        results(si, pi).t = t;
        results(si, pi).imp = h;          % FIR impulse IS h itself
        results(si, pi).f = f_norm;
        results(si, pi).Hmag = Hmag;

    end
end


%% ---------------------------------------------------------
%  PLOT IMPULSE RESPONSES FOR ALL span × sps COMBINATIONS
% ---------------------------------------------------------

figure('Name','Impulse Responses for All span × sps');

plot_index = 1;

for si = 1:length(span_values)
    for pi = 1:length(sps_values)

        subplot(length(span_values), length(sps_values), plot_index);
        plot(results(si,pi).t, results(si,pi).imp, 'LineWidth', 1.2);
        grid on;

        title(sprintf('span=%d, sps=%d', ...
            results(si,pi).span, results(si,pi).sps));

        xlabel('Time (symbols)');
        ylabel('Amplitude');

        plot_index = plot_index + 1;
    end
end


%% ---------------------------------------------------------
%  PLOT FREQUENCY RESPONSES FOR ALL span × sps COMBINATIONS
% ---------------------------------------------------------

figure('Name','Frequency Responses for All span × sps');

plot_index = 1;

for si = 1:length(span_values)
    for pi = 1:length(sps_values)

        subplot(length(span_values), length(sps_values), plot_index);
        plot(results(si,pi).f, 20*log10(results(si,pi).Hmag + 1e-12), 'LineWidth', 1.2);
        grid on;

        title(sprintf('span=%d, sps=%d', ...
            results(si,pi).span, results(si,pi).sps));

        xlabel('Normalized Frequency (× symbol rate)');
        ylabel('Magnitude (dB)');

        plot_index = plot_index + 1;
    end
end
