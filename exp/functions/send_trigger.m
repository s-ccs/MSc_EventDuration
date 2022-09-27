function send_trigger(varargin)

if nargin <1
    message = '';
else
    message = varargin{1};
end
if nargin < 2
    time = GetSecs-startTime;
else
    time = varargin{2};
end

cfg=varargin{3};

% Send LSL triggers
if cfg.use_lsl
    if strcmp(message,'buttonpress')
        triggerNum = sprintf('%s:%.4f',message,time);
        % LSL timestamp is corrected by time between buttonpress and time
        % where trigger is sent - according to psychtoolbox clock (GetSecs)
        cfg.outlet.push_sample({triggerNum},lsl_local_clock(cfg.info.LibHandle)-(GetSecs()-varargin{4}));
    else
        triggerNum = sprintf('%s:%.4f',message,time);
        cfg.outlet.push_sample({triggerNum});
    end
end

% Send EEG markers
% if cfg.use_lpt
%     fprintf(cfg.s, 'WRITE %i 10000 0\n',triggerNum);
% end
if cfg.do_P300
    if cfg.use_lpt
        if strcmp(message,'buttonpress')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',4);
        elseif strcmp(message,'blockStart')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',1);
        elseif strcmp(message,'blockEnd')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',5);
        elseif strcmp(message,'stimOnset')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',2);
        elseif strcmp(message,'stimOffset')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',3);
        end
    end
    WaitSecs(0.01);
elseif cfg.do_stimDur
    if cfg.use_lpt
        if strcmp(message,'buttonpress')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',4);
        elseif strcmp(message,'blockStart')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',1);
        elseif strcmp(message,'blockEnd')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',5);
        elseif strcmp(message,'stimOnset')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',2);
        elseif strcmp(message,'stimOffset')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',3);
        elseif strcmp(message,'distracterOnset')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',6);
        elseif strcmp(message,'distracterOffset')
            fprintf(cfg.s, 'WRITE %i 10000 0\n',7);
        end
    end
    WaitSecs(0.003);
end
end