% Same with C#
global p; p = 9;
global N; N = 2^p;
%   Physical param
global g; g = 9.8;
global d; d = 20; %(meter)
global V; V = 4; % 2: calm, 4: normal, 6: windy

global h_tilde; h_tilde = zeros(N, N);
h_tilde_xy = zeros(N, N, 2);
omega = zeros(N, N);

tic;
for u = 1:N
    for v = 1:N
        kx = 2*pi * (mod(u-1+N/2, N) - N/2) / d;
        ky = 2*pi * (mod(v-1+N/2, N) - N/2) / d;
        [phi, k] = cart2pol(kx, ky); phi = phi - pi/4;
        omega(u, v) = sqrt(g*k);
        h_tilde(u, v) = 1/sqrt(2) * ...
            (normrnd(0,1) + 1i*normrnd(0,1)) * ...
            sqrt(Ph(k, phi));
        h_tilde_xy(u, v, 1) = kx/k*h_tilde(u, v);
        h_tilde_xy(u, v, 2) = ky/k*h_tilde(u, v);
    end
end
toc;
