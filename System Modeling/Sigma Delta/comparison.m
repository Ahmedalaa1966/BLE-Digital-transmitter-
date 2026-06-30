clc; clear; close all;

% Load Modeling (MATLAB)

model_data = readmatrix('Modeling_output.txt');   % L x N

% Load Implementation (Verilog)
impl_data = [];

fid = fopen('Implementation_output.txt','r');

while ~feof(fid)
    line = fgetl(fid);
    if ischar(line) && ~isempty(strtrim(line))
        nums = str2num(line); %#ok<ST2NM>
        impl_data = [impl_data; nums]; %#ok<AGROW>
    end
end

fclose(fid);


% Check size

if ~isequal(size(model_data), size(impl_data))
    error('❌ Size mismatch between files!');
end


% 🔥 Convert to ROW-WISE sequence
model_vec = reshape(model_data.', [], 1);
impl_vec  = reshape(impl_data.', [], 1);


% Plot overlay
figure;
plot(model_vec, 'o-', 'LineWidth', 1.5); hold on;
plot(impl_vec, 'x--', 'LineWidth', 1.5);

grid on;
legend('Modeling (MATLAB)', 'Implementation (Verilog)');
title('MATLAB vs Verilog Output Comparison');
xlabel('Sample Index');
ylabel('SD Output');

ylim([-4 4]);   % 🔥 fixed y-axis

% Error plot

err = model_vec - impl_vec;

figure;
stem(err, 'filled');
grid on;
title('Error (Model - Implementation)');
xlabel('Sample Index');
ylabel('Error');

ylim([-4 4]);   % 🔥 fixed y-axis

% Numerical check
if all(err == 0)
    disp("✅ PERFECT MATCH: Modeling == Implementation");
else
    disp("❌ Mismatch detected!");
    
    idx = find(err ~= 0);
    disp("Mismatch indices:");
    disp(idx);

    disp("Model values:");
    disp(model_vec(idx));

    disp("Implementation values:");
    disp(impl_vec(idx));
end