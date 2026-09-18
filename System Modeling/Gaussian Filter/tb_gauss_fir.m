% Generate NRZ sample stream
numSymbols = 20;
sps = 16;
bits = randi([0 1], numSymbols, 1);
nrz  = 2*bits - 1;
x    = repelem(nrz, sps);

y = zeros(size(x));

for n = 1:length(x)
    y(n) = gauss_fir_step(x(n));   % one sample per "clock"
end

plot(y); grid on;
title('Sample-Based Gaussian FIR Output');
