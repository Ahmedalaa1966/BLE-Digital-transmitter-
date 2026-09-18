function y = gauss_fir_step(xn)
% Sample-based EVEN-length symmetric Gaussian FIR
% Call once per input sample
% Internal state is persistent (RTL-style)

    %% ------------------------
    % Persistent state
    %% ------------------------
    persistent delayLine h L pairs initialized

    if isempty(initialized)
        %% Parameters (must match your original script)
        BT   = 0.5;
        span = 4;
        sps  = 16;

        L = span * sps;        % 64 taps (EVEN)
        pairs = L / 2;

        Ts_sym = 1 / sps;
        t0 = span / 2;

        % Half-sample-shifted grid
        t = (-t0 + Ts_sym/2) : Ts_sym : (t0 - Ts_sym/2);

        % Gaussian sigma
        sigma = sqrt(log(2)) / (2*pi*BT);

        % Impulse response
        g = exp(-(t.^2) / (2*sigma^2));
        h = g(:);
        h = h / sum(h);

        % Delay line
        delayLine = zeros(L,1);

        initialized = true;
    end

    %% ------------------------
    % Shift register (1 sample per call = 1 clock)
    %% ------------------------
    delayLine = [xn; delayLine(1:end-1)];

    %% ------------------------
    % Symmetric multiplier-free FIR
    %% ------------------------
    acc = 0;

    for k = 1:pairs
        s = delayLine(k) + delayLine(L-k+1);  % {-2,0,+2}

        if s == 2
            acc = acc + 2*h(k);
        elseif s == -2
            acc = acc - 2*h(k);
        end
    end

    y = acc;
end
