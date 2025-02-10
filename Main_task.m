%% spatial mapping when subjects fixate at the fixation-- sirawaj itthipuripat 2017
%%
clear;
close all;

%% get subject info
prompt = {'Subject', 'Session' ,'Block', 'Sex', 'Hand', 'Age', 'tg contrast', 'task type: foc (1-6) div (7) and fixation (8)'};

%fill in some stock answers to the gui input boxes
defAns = {'1','1', '1' , 'm',  'r', '18', '.98', '1'};
box = inputdlg(prompt,'Enter Subject Information...', 1, defAns);
if length(box)==length(defAns)      %simple check for enough input, otherwise bail out
    p.subNum=str2double(box{1});
    p.sessType=str2double(box{2});
    p.runNum=str2double(box{3});
    p.sex = box{4};
    p.hand = box{5};
    p.age = str2double(box{6});
    p.tgcontrast = str2double(box{7});
    p.tasktype = str2double(box{8});
    
else    %if cancel button or not enough input, then just bail
    return
end

ListenChar(2);

%build an output file name and check to make sure that it does not exist already
p.root = pwd;
if ~exist([p.root, '/Subject_Data/'], 'dir')
    mkdir([p.root, '/Subject_Data/']);
end

fName=[p.root, '/Subject_Data/MainTask' num2str(p.tasktype) '_sbj', num2str(p.subNum), '_sess', num2str(p.sessType), '_block', num2str(p.runNum), '.mat'];
if exist(fName,'file')
    Screen('CloseAll');
    msgbox('File name already exists, please specify another', 'modal');
    ListenChar(0);
    return
end

%% set up screen - load the CLUT to get the correct gamma value, open a
% screen that is filled with grey

AssertOpenGL;
% Open onscreen window:

load correctGammafMRI
p.LUT = correctGamma*255;

% window characteristics:
screen=max(Screen('Screens'));
[win, scr_rect] = Screen('OpenWindow', 0);
[winWidth, winHeight]=Screen('WindowSize', win);
black= 1;white=255;
background= p.LUT(127); % background color
textcolor=white;
xcenter=winWidth/2; % center is at the upper right corner
ycenter=winHeight/2;
% Fill screen with background color:
Screen('FillRect', win, background);
% Initial display and sync to timestamp:
[VBLTimestamp ringOnset FlipTimestamp Missed Beampos]=Screen(win, 'Flip');

%% set letter details

Font='Arial'; Screen('TextSize',win,25); Screen('TextFont',win,Font); Screen('TextColor',win,white);
HideCursor;


Screen('BlendFunction',win,GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

%% stimulus parameters
%position of target and checkerboard
Rec= 180; % stim distance from fixation
Rfix = 6; % radius of fixation
Rring = 15;
Rstim = 100; % radius of stimulus (px)

xnum = 8;
ynum = 3;

xx1 = ((0:1/(xnum-1):1)-.5)*2*.85;
dgrid = xx1(2)-xx1(1);
xx2 = -dgrid*floor((xnum-1)/2):dgrid:dgrid*floor((xnum-1)/2);

if mod(ynum, 2) ==1
    yy = -dgrid*floor(ynum/2):dgrid:dgrid*floor(ynum/2);
else
    yy = -dgrid*floor(ynum/2)+dgrid/2:dgrid:dgrid*floor(ynum/2)-dgrid/2;
end

xpos = [xx2 xx1 xx2];
ypos = [ones(1, numel(xx2))*yy(1) ones(1, numel(xx1))*yy(2) ones(1, numel(xx2))*yy(3) ];


respCode =KbName('b'); %dectection button
abortKey = KbName('q');

ct = [.98 .96 .94 1];

for ctt = 1:4
check = make_checkerboard(Rstim,2*Rstim/3, ct(ctt)); % make a small checkerboard
checktext{ctt}=Screen('MakeTexture', win, check{1}); % put all stimululi in the texture with contrast reversal
fix = make_checkerboard(Rfix,2*Rstim/3, ct(ctt)); % make a small checkerboard
fixtext{ctt}=Screen('MakeTexture', win, fix{1}); % put all stimululi in the texture with contrast reversal
end



LocX = xcenter+winWidth/2*xpos;
LocY = ycenter+winWidth/2*ypos;
p.LocX =LocX;
p.LocY = LocY;
tgloc = 9:14;
%% start presentation

%% set up the entire trials for each block
p.uniqueloc = numel(tgloc);


if ismember(p.tasktype, 1:6)
    p.stimloc = [tgloc tgloc tgloc ones(1,36)*tgloc(p.tasktype) repmat(tgloc, [1, 17])];
    p.tgntg = [ones(1, 6) ones(1, 6)*2 ones(1, 6)*3 repmat(1:3, [1, 12]) zeros(1, 102)];
elseif p.tasktype >= 7
    p.stimloc = [repmat(tgloc, [1, 9]) repmat(tgloc, [1, 17])];
    p.tgntg = [ones(1, 18) ones(1, 19)*2 ones(1, 18)*3 zeros(1, 102)];
end

p.tnumb = numel(p.stimloc);
p.trialorder = Shuffle(1:p.tnumb); % randomize trial order
p.tgntg = p.tgntg(p.trialorder);
p.stimloc = p.stimloc(p.trialorder);
p.ITIs = Shuffle(linspace(.55,.95,p.tnumb)); %
stimDur = .3; % stimulus duration/ total --> 168s in total
%p.trialdur = stimDur+p.ITIs; % total trial duration + ITI
p.hit = zeros(1, p.tnumb);
p.fa = zeros(1, p.tnumb);
p.RT = nan(1, p.tnumb);
p.stimdur = zeros(1, p.tnumb);
p.ITIdur = zeros(1, p.tnumb);
p.tasktypex = zeros(1, p.tnumb) + p.tasktype;
%% instruction
if ismember(p.tasktype, 1:6)
    DrawFormattedText(win,'Detect contrast dimming at the stimulus locations!', 'center', ycenter+40 ,  black);
    DrawFormattedText(win,'The red location is the most probable!', 'center', ycenter+70 ,  black);
elseif p.tasktype == 7
    DrawFormattedText(win,'Detect contrast dimming at the stimulus locations!', 'center', ycenter+40 ,  black);
    DrawFormattedText(win,'All red locations are equally probable!', 'center', ycenter+70 ,  black);
elseif p.tasktype == 8
    DrawFormattedText(win,'Detect contrast dimming at the central fixation!', 'center', ycenter+40 ,  black);
    DrawFormattedText(win,'Fixation only!', 'center', ycenter+70 ,  black);
end

cc = 0;
clear cuecolor
for cue = tgloc
    cc = cc+1;
    if ismember(p.tasktype, 1:6)
        if p.tasktype ~=cc
            cuecolor = [0 0 0];
        else
            cuecolor = [255 0 0];
        end
    elseif p.tasktype == 7
        cuecolor = [255 0 0];
    elseif p.tasktype == 8
        cuecolor = background;
    end
    
    Screen('FillOval',win, cuecolor, ...
        [LocX(cue)-Rfix LocY(cue)-Rfix LocX(cue)+Rfix LocY(cue)+Rfix], 15);
end


Screen('DrawTexture', win, fixtext{1}, ...
    [], [xcenter-Rfix ycenter(1)-Rfix xcenter+Rfix ycenter+Rfix],0); %fixation
[VBLTimestamp, Begin_Time]=Screen(win, 'Flip');
KbWait; %

Screen('DrawTexture', win, fixtext{1, 1}, ...
    [], [xcenter-Rfix ycenter(1)-Rfix xcenter+Rfix ycenter+Rfix],0); %fixation
[VBLTimestamp, Begin_Time]=Screen(win, 'Flip');
WaitSecs(2);


%% t loop
for t = 1:p.tnumb
    
    stimlocx = p.stimloc(t);
    press = 0;
    
    
    f = 0;
    tgon = 0;
    tgonset = 0;
    while p.stimdur(t) <= stimDur
        f = f+1;
        stim = 4;
        if p.tgntg(t) >=1 && p.stimdur(t) >= .1 && p.stimdur(t) <= .2
            stim = p.tgntg(t);
            tgon = 1;
            if tgonset == 0
                tgonset = GetSecs;
            end
        end
        
        if p.tasktype <=7
            Screen('DrawTexture', win, checktext{stim}, ...
                [],[LocX(stimlocx)-Rstim LocY(stimlocx)-Rstim LocX(stimlocx)+Rstim LocY(stimlocx)+Rstim], 0);
            Screen('FillOval',win,background,[xcenter-Rring ycenter(1)-Rring xcenter+Rring ycenter+Rring],[]); %fixation
            Screen('DrawTexture', win, fixtext{4}, ...
                [], [xcenter-Rfix ycenter(1)-Rfix xcenter+Rfix ycenter+Rfix],0); %fixation
        else
            Screen('DrawTexture', win, checktext{4}, ...
                [],[LocX(stimlocx)-Rstim LocY(stimlocx)-Rstim LocX(stimlocx)+Rstim LocY(stimlocx)+Rstim], 0);
            Screen('FillOval',win,background,[xcenter-Rring ycenter(1)-Rring xcenter+Rring ycenter+Rring],[]); %fixation
            Screen('DrawTexture', win, fixtext{stim}, ...
                [], [xcenter-Rfix ycenter(1)-Rfix xcenter+Rfix ycenter+Rfix],0); %fixation
        end
        if press == 0
            [key_was_pressed, press_time, key_list] = KbCheck; % check responses
            if key_was_pressed
                key_code = find(key_list);
                
                if key_code==abortKey % abort key
                    
                    ListenChar(0);
                    ShowCursor;
                    clear screen;
                    Screen('CloseAll');
                elseif  key_code(1) == respCode(1)
                    press = 1;
                    if p.tgntg(t) >=1 && tgon ==1
                        p.RT (t) = press_time -tgonset;
                        p.hit(t) = 1;
                    else
                        p.fa(t) = 1;
                    end
                end
                
            end
        end
        [VBLTimestamp, Begin_Time]=Screen(win, 'Flip');
        if f == 1
            stimonset = VBLTimestamp;
        end
        p.stimdur(t) = GetSecs - stimonset;
    end
    
    
    
    c = 0;
    while p.ITIdur(t) <= p.ITIs(t)
        c= c+1;
        Screen('DrawTexture', win, fixtext{1}, ...
            [], [xcenter-Rfix ycenter(1)-Rfix xcenter+Rfix ycenter+Rfix],0); %fixation %% collect response
        if press == 0
            [key_was_pressed, press_time, key_list] = KbCheck; % check responses
            if key_was_pressed
                key_code = find(key_list);
                
                if key_code==abortKey % abort key
                    
                    ListenChar(0);
                    ShowCursor;
                    clear screen;
                    Screen('CloseAll');
                elseif  key_code(1) == respCode(1)
                    press = 1;
                    if p.tgntg(t) >=1 && tgon ==1
                        p.RT (t) = press_time -tgonset;
                        p.hit(t) = 1;
                    else
                        p.fa(t) = 1;
                    end
                end
                
            end
        end
        if c ==1
            [VBLTimestamp, Begin_Time]=Screen(win, 'Flip');
            p.stimdur(t) = VBLTimestamp-stimonset;
        end
        p.ITIdur(t)= GetSecs-VBLTimestamp;
    end
end

Screen('DrawTexture', win, fixtext{1, 1}, ...
    [], [xcenter-Rfix ycenter(1)-Rfix xcenter+Rfix ycenter+Rfix],0); %fixation
Screen(win, 'Flip');
WaitSecs (2); % add 8 sec for hdr to come down


hit_circle = mean(p.hit(p.tgntg>=1));
fa_circle = mean(p.fa(p.tgntg==0));

DrawFormattedText(win,['hit =' num2str(hit_circle) ' / fa =' num2str(fa_circle) ], 'center', ycenter+20 ,  black);
Screen('DrawTexture', win, fixtext{1, 1}, ...
    [], [xcenter-Rfix ycenter(1)-Rfix xcenter+Rfix ycenter+Rfix],0); %fixation
Screen(win, 'Flip');
KbWait;


%save trial data from this block
save(fName, 'p');

ShowCursor;
ListenChar(0);
Screen('CloseAll');


