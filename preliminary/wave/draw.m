anime = timer;
anime.TimerFcn = {@draw_func, h_tilde, h_tilde_xy, omega};
anime.Period = 0.05;
anime.ExecutionMode = 'fixedSpacing';
start(anime);
