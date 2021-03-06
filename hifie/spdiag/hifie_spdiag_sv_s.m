% HIFIE_SPDIAG_SV_S  Dispatch for HIFIE_SPDIAG with DINV = 1 and F.SYMM = 'S'.

function D = hifie_spdiag_sv_s(F,spinfo)

  % initialize
  N = F.N;
  n = length(spinfo.i);
  P = zeros(N,1);
  D = zeros(N,1);

  % loop over all leaf blocks from top to bottom
  for i = n:-1:1

    % find active indices for current block
    rem = spinfo.t{i};
    rem = unique([[F.factors(rem).sk] [F.factors(rem).rd]]);
    nrem = length(rem);
    P(rem) = 1:nrem;

    % allocate active submatrix for current block
    j = spinfo.i(i);
    sk = F.factors(j).sk;
    rd = F.factors(j).rd;
    slf = [sk rd];
    nslf = length(slf);
    Y = zeros(nrem,nslf);
    Y(P(slf),:) = eye(nslf);

    % upward sweep
    for j = spinfo.t{i}
      if j > 0
        sk = P(F.factors(j).sk);
        rd = P(F.factors(j).rd);
        Y(rd,:) = Y(rd,:) - F.factors(j).T.'*Y(sk,:);
        Y(rd,:) = F.factors(j).L\Y(rd,:);
        Y(sk,:) = Y(sk,:) - F.factors(j).E*Y(rd,:);
      end
    end

    % downward sweep
    for j = spinfo.t{i}(end:-1:1)
      if j > 0
        sk = P(F.factors(j).sk);
        rd = P(F.factors(j).rd);
        Y(rd,:) = Y(rd,:) - F.factors(j).F*Y(sk,:);
        Y(rd,:) = F.factors(j).U\Y(rd,:);
        Y(sk,:) = Y(sk,:) - F.factors(j).T*Y(rd,:);
      end
    end

    % extract diagonal
    D(slf) = diag(Y(P(slf),:));
  end
end