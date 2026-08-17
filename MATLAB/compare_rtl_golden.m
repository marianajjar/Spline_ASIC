function [ok, offset, nbad] = compare_rtl_golden(rtl_file, dacI, dacQ)
% COMPARE_RTL_GOLDEN  Compare RTL output against golden model bit-exactly.

    [rtlI, rtlQ] = read_hex_pairs(rtl_file);

    dacI = double(dacI(:));
    dacQ = double(dacQ(:));

    Ng = numel(dacI);
    Nr = numel(rtlI);

    if Nr < Ng
        error('RTL output (%d) shorter than golden (%d)', Nr, Ng);
    end

    best_off = 0;
    best_bad = inf;

    for off = 0:(Nr - Ng)
        rI_try = rtlI(off+1:off+Ng);
        rQ_try = rtlQ(off+1:off+Ng);

        bI = sum(dacI ~= rI_try);
        bQ = sum(dacQ ~= rQ_try);

        if (bI + bQ) < best_bad
            best_bad = bI + bQ;
            best_off = off;
        end

        if best_bad == 0
            break;
        end
    end

    offset = best_off;
    nbad   = best_bad;
    ok     = (nbad == 0);

    fprintf('compare_rtl_golden: golden=%d samples, rtl=%d samples\n', Ng, Nr);
    fprintf('  best offset = %d,  mismatches = %d (I+Q)\n', offset, nbad);

    rI = rtlI(offset+1:offset+Ng);
    rQ = rtlQ(offset+1:offset+Ng);

    if ok
        fprintf('  RESULT: BIT-EXACT MATCH ✓\n');
    else
        kI = find(dacI ~= rI, 1, 'first');
        kQ = find(dacQ ~= rQ, 1, 'first');

        if ~isempty(kI)
            fprintf('  RESULT: I MISMATCH at golden index %d: golden=%d  rtl=%d\n', ...
                    kI, dacI(kI), rI(kI));
        end

        if ~isempty(kQ)
            fprintf('  RESULT: Q MISMATCH at golden index %d: golden=%d  rtl=%d\n', ...
                    kQ, dacQ(kQ), rQ(kQ));
        end

        fprintf('  (max |error| I = %d, Q = %d)\n', ...
                max(abs(dacI - rI)), max(abs(dacQ - rQ)));
    end
end

function [I, Q] = read_hex_pairs(fname)
    fid = fopen(fname, 'r');
    if fid < 0
        error('cannot open %s', fname);
    end

    I = [];
    Q = [];

    while true
        ln = fgetl(fid);

        if ~ischar(ln)
            break;
        end

        ln = strtrim(ln);

        if isempty(ln)
            continue;
        end

        t = sscanf(ln, '%x %x');

        if numel(t) == 2
            I(end+1,1) = s16(t(1)); %#ok<AGROW>
            Q(end+1,1) = s16(t(2)); %#ok<AGROW>
        end
    end

    fclose(fid);
end

function v = s16(u)
    u = mod(u, 65536);
    v = u - 65536 * (u >= 32768);
end
