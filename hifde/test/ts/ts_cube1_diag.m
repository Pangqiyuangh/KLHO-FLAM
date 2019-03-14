% Seven-point stencil on the unit cube, constant-coefficient Poisson, Dirichlet
% boundary conditions.



  % set default parameters
vd = [4:0.25:6];
time = zeros(length(vd),2);
timefac = zeros(length(vd),1);
rele = zeros(length(vd),2);
NN = zeros(length(vd),1);
for nn = 1:length(vd)
    n = round(2^vd(nn));
    occ = 4;
    rank_or_tol = 1e-6;
    skip = 2;
    symm = 'p';
    spdiag = 0;

  % initialize
  N = (n - 1)^3;
  h = 1/n;

  % set up indices
  idx = zeros(n+1,n+1,n+1);
  idx(2:n,2:n,2:n) = reshape(1:N,n-1,n-1,n-1);
  mid = 2:n;
  lft = 1:n-1;
  rgt = 3:n+1;

  % interactions with left node
  Il = idx(mid,mid,mid);
  Jl = idx(lft,mid,mid);
  Sl = -1/h^2*ones(size(Il));

  % interactions with right node
  Ir = idx(mid,mid,mid);
  Jr = idx(rgt,mid,mid);
  Sr = -1/h^2*ones(size(Ir));

  % interactions with bottom node
  Id = idx(mid,mid,mid);
  Jd = idx(mid,lft,mid);
  Sd = -1/h^2*ones(size(Id));

  % interactions with top node
  Iu = idx(mid,mid,mid);
  Ju = idx(mid,rgt,mid);
  Su = -1/h^2*ones(size(Iu));

  % interactions with back node
  Ib = idx(mid,mid,mid);
  Jb = idx(mid,mid,lft);
  Sb = -1/h^2*ones(size(Ib));

  % interactions with front node
  If = idx(mid,mid,mid);
  Jf = idx(mid,mid,rgt);
  Sf = -1/h^2*ones(size(If));

  % interactions with self
  Im = idx(mid,mid,mid);
  Jm = idx(mid,mid,mid);
  Sm = -(Sl + Sr + Sd + Su + Sb + Sf);

  % form sparse matrix
  I = [Il(:); Ir(:); Id(:); Iu(:); Ib(:); If(:); Im(:)];
  J = [Jl(:); Jr(:); Jd(:); Ju(:); Jb(:); Jf(:); Jm(:)];
  S = [Sl(:); Sr(:); Sd(:); Su(:); Sb(:); Sf(:); Sm(:)];
  idx = find(J > 0);
  I = I(idx);
  J = J(idx);
  S = S(idx);
  A = sparse(I,J,S,N,N);
  clear idx Il Jl Sl Ir Jr Sr Id Jd Sd Iu Ju Su Ib Jb Sb If Jf Sf Im Jm Sm I J S

  % factor matrix
  opts = struct('skip',skip,'symm',symm,'verb',1);
  [F,tt] = hifde3(A,n,occ,rank_or_tol,opts);
  w = whos('F');
  fprintf([repmat('-',1,80) '\n'])
  fprintf('mem: %6.2f (MB)\n', w.bytes/1e6)

  % test accuracy using randomized power method
  X = rand(N,1);
  X = X/norm(X);

  % NORM(A - F)/NORM(A)
  tic
  hifde_mv(F,X);
  t = toc;
  [e,niter] = snorm(N,@(x)(A*x - hifde_mv(F,x)),[],[],1);
  e = e/snorm(N,@(x)(A*x),[],[],1);
  fprintf('mv: %10.4e / %4d / %10.4e (s)\n',e,niter,t)

  % NORM(INV(A) - INV(F))/NORM(INV(A)) <= NORM(I - A*INV(F))
  tic
  Y = hifde_sv(F,X);
  t = toc;
  [e,niter] = snorm(N,@(x)(x - A*hifde_sv(F,x)),@(x)(x - hifde_sv(F,A*x,'c')));
  fprintf('sv: %10.4e / %4d / %10.4e (s)\n',e,niter,t)

  % prepare for diagonal extracation
  opts = struct('verb',1);
  r = randperm(N);
  m = min(N,128);
  r = r(1:m);
  X = zeros(N,m);
  for i = 1:m
    X(r(i),i) = 1;
  end
  E = zeros(m,1);

  % extract diagonal
  if spdiag
    tic
    D = hifde_spdiag(F);
    t1 = toc;
  else
    [D,t1] = hifde_diag(F,0,opts);
  end
  Y = hifde_mv(F,X);
  for i = 1:m
    E(i) = Y(r(i),i);
  end
  e1 = norm(D(r) - E)/norm(E);
  if spdiag
    fprintf('spdiag_mv: %10.4e / %10.4e (s)\n',e1,t1)
  end

  % extract diagonal of inverse
  if spdiag
    tic
    D = hifde_spdiag(F,1);
    t2 = toc;
  else
    [D,t2] = hifde_diag(F,1,opts);
  end
  Y = hifde_sv(F,X);
  for i = 1:m
    E(i) = Y(r(i),i);
  end
  e2 = norm(D(r) - E)/norm(E);
  if spdiag
    fprintf('spdiag_sv: %10.4e / %10.4e (s)\n',e2,t2)
  end

  % print summary
  if ~spdiag
    fprintf([repmat('-',1,80) '\n'])
    fprintf('diag: %10.4e / %10.4e\n',e1,e2)
  end
  
  time(nn,1) = t1;
  time(nn,2) = t2;
  timefac(nn,1) = tt;
  rele(nn,1) = e1;
  rele(nn,2) = e2;
  NN(nn,1) = log2(N);
end
    figure('visible','off');
    pic = figure;
    hold on;
    ag = (log2(time(1,1))+log2(time(1,2))+log2(timefac(1)))/3;
    h(1) = plot(NN,NN+log2(NN)-NN(1)-log2(NN(1))+ag,'--k','LineWidth',2);
    h(2) = plot(NN,NN-NN(1)+ag,'--b','LineWidth',2);
    h(3) = plot(NN,2*NN-2*NN(1)+ag,'--r','LineWidth',2);
    h(4) = plot(NN,log2(time(:,1)),'-^r','LineWidth',2);
    h(5) = plot(NN,log2(time(:,2)),'-^g','LineWidth',2);
    h(6) = plot(NN,log2(timefac),'-^c','LineWidth',2);
    legend('N log(N)','N','N^2','diag','diag inv','HIF','Location','NorthWest');
    if spdiag
       title('Extract diag via sparse apply/solves, time');
    else
       title('Extract diag via matrix unfolding, time');
    end
    axis tight;
    xlabel('log_2(N)'); ylabel('log_{2}(time)');
    set(gca, 'FontSize', 20);
    b=get(gca);
    set(b.XLabel, 'FontSize', 20);set(b.YLabel, 'FontSize', 20);set(b.ZLabel, 'FontSize', 20);set(b.Title, 'FontSize', 20);
    if spdiag
       saveas(pic,['ts_cube1_spdiag_time.eps'],'epsc');
    else
       saveas(pic,['ts_cube1_diag_time.eps'],'epsc');
    end
    hold off;
    pic = figure;
    hold on;
    ag = (log10(rele(1,1))+log10(rele(1,2)))/2;
    h(1) = plot(NN,log10(rele(:,1)),'-^r','LineWidth',2);
    h(2) = plot(NN,log10(rele(:,2)),'-^g','LineWidth',2);
    legend('diag','diag inv','Location','NorthWest');
    if spdiag
       title('Extract diag via sparse apply/solves, accuracy');
    else
       title('Extract diag via matrix unfolding, accuracy');
    end
    axis tight;
    xlabel('log_2(N)'); ylabel('log_{10}(accuracy)');
    set(gca, 'FontSize', 20);
    b=get(gca);
    set(b.XLabel, 'FontSize', 20);set(b.YLabel, 'FontSize', 20);set(b.ZLabel, 'FontSize', 20);set(b.Title, 'FontSize', 20);
    if spdiag
       saveas(pic,['ts_cube1_spdiag_accu.eps'],'epsc');
    else
       saveas(pic,['ts_cube1_diag_accu.eps'],'epsc');
    end
    hold off;
