function writeBin(fileName)
    global h_tilde;

    fp = fopen([fileName '.bytes'], 'w');

    C(1,:,:) = real(h_tilde);
    C(2,:,:) = imag(h_tilde);
    fwrite(fp, C, 'single');
    fclose(fp);
end
