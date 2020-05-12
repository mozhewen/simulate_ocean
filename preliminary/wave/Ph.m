function y = Ph(k, phi)
    global g d V;
    L= V^2/g; A = 0.02*(2*pi/d)^2;

    if k > 0
        y = A.*exp(-1./(k.*L).^2)./(k).^4.*cos(phi).^2;
    else
        y = 0;
    end
end
