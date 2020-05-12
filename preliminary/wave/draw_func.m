function draw_func(~, ~, h_tilde, h_tilde_xy, omega)
    persistent t;
    global N;
    global d;

    if isempty(t)
        t = 0;
    else
        t = t + 0.05;
    end

    t_factor = exp(-1i.* omega * t);
    
    h = real(fft2(h_tilde.*t_factor));
    dx = imag(fft2(h_tilde_xy(:,:,1).*t_factor));
    dy = imag(fft2(h_tilde_xy(:,:,2).*t_factor));
    
    lst = linspace(1,N+1,129);
    lst = lst(1:end-1);
    [y, x] = meshgrid(lst, lst);
    x = x + dx(lst, lst) /d * N;
    y = y + dy(lst, lst) /d * N;
    surf(x, y, h(lst, lst), 'EdgeColor', 'none');
    axis(gca, [1 N 1 N -10 10]);
    xlabel('x/m(Direction of wind)');
    xticks(linspace(0, N, 11));
    xticklabels(num2cell(linspace(0, 20, 11)));
    yticks(linspace(0, N, 11));
    yticklabels(num2cell(linspace(0, 20, 11)));
    ylabel('y/m');
    zlabel('z/m');
    set(gca, 'Projection', 'perspective',...)
         'DataAspectRatioMode', 'auto',...
         'PlotBoxAspectRatioMode', 'manual');
     drawnow;
end
