function varargout = plexme(varargin)
% PLEXME MATLAB code for plexme.fig
%      PLEXME, by itself, creates a new PLEXME or raises the existing
%      singleton*.
%
%      H = PLEXME returns the handle to a new PLEXME or the handle to
%      the existing singleton*.
%
%      PLEXME('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PLEXME.M with the given input arguments.
%
%      PLEXME('Property','Value',...) creates a new PLEXME or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before plexme_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to plexme_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help plexme

% Last Modified by GUIDE v2.5 11-May-2015 13:19:27

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @plexme_OpeningFcn, ...
                   'gui_OutputFcn',  @plexme_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT




function [ intan_pin] = map_plexon_pin_to_intan(plexon_pin)
intan_pin = handles.PIN_NAMES(2, find(handles.PIN_NAMES(1,:) == plexon_pin));


function [ plexon_pin] = map_intan_pin_to_plexon(intan_pin)
plexon_pin = handles.PIN_NAMES(1, find(handles.PIN_NAMES(2,:) == intan_pin));



% --- Executes just before plexme is made visible.
function plexme_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to plexme (see VARARGIN)


% Choose default command line output for plexme
handles.output = hObject;

handles.START_uAMPS = 10;
handles.MAX_uAMPS = 200;
handles.INCREASE_STEP = 1.1;
handles.change = handles.INCREASE_STEP;
handles.HALF_TIME_uS = 400;
handles.INTERSPIKE_S = 1;
handles.NEGFIRST = false;
handles.valid = zeros(1, 16);
handles.monitor_electrode = ' ';
handles.stim = zeros(1, 16);  % Stimulate these electrodes
handles.timer = [];
handles.stimAll = false;

global CURRENT_uAMPS;
CURRENT_uAMPS = handles.START_uAMPS;

% Top row is the names of pins on the Plexon.  Bottom row is corresponding
% pins on the Intan.
handles.PIN_NAMES = [ 1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16 ; ...
                      0  0  0  0  0  0  0  0  0   0   0   0   0   0   0   0 ];


set(handles.startcurrent, 'String', sprintf('%d', round(handles.START_uAMPS)));
set(handles.currentcurrent, 'String', sprintf('%.3g', CURRENT_uAMPS));
set(handles.maxcurrent, 'String', sprintf('%d', round(handles.MAX_uAMPS)));
set(handles.increasefactor, 'String', sprintf('%g', handles.INCREASE_STEP));
set(handles.halftime, 'String', sprintf('%d', round(handles.HALF_TIME_uS)));
set(handles.delaytime, 'String', sprintf('%g', handles.INTERSPIKE_S));
set(handles.negativefirst, 'Value', handles.NEGFIRST);
set(handles.stim_all, 'Value', handles.stimAll);
set(handles.monitor_electrode_control, 'String', {' '}, 'Value', 1);

handles.disable_on_run = { handles.currentcurrent, handles.startcurrent, ...
        handles.maxcurrent, handles.increasefactor, handles.halftime, handles.delaytime};
for i = 1:16
        cmd = sprintf('handles.disable_on_run{end+1} = handles.electrode%d', i);
        eval(cmd);
        cmd = sprintf('handles.disable_on_run{end+1} = handles.stim%d', i);
        eval(cmd);
end

for i = 1:16
        cmd = sprintf('set(handles.electrode%d, ''Value'', 0)', i);
        eval(cmd);
        cmd = sprintf('set(handles.stim%d, ''Enable'', ''off'')', i);
        eval(cmd);
        cmd = sprintf('set(handles.stim%d, ''Value'', false)', i);
        eval(cmd);
end
              
% Update handles structure

guidata(hObject, handles);




% UIWAIT makes plexme wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = plexme_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;




% --- Executes on button press in negativefirst.
function negativefirst_Callback(hObject, eventdata, handles)
handles.NEGFIRST = get(hObject, 'Value');
guidata(hObject, handles);



function startcurrent_Callback(hObject, eventdata, handles)
handles.START_uAMPS = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function startcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function maxcurrent_Callback(hObject, eventdata, handles)
handles.MAX_uAMPS = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function maxcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




function increasefactor_Callback(hObject, eventdata, handles)
handles.INCREASE_STEP = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function increasefactor_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function halftime_Callback(hObject, eventdata, handles)
handles.HALF_TIME_uS = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function halftime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function delaytime_Callback(hObject, eventdata, handles)
handles.INTERSPIKE_S = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function delaytime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function electrode_universal_callback(hObject, eventdata, handles)
whichone = str2num(hObject.String);
value = get(hObject, 'Value');
handles.valid(whichone) = value
if handles.valid(whichone)
        newstate = 'on';
else
        newstate = 'off';
end
% "stimulate this electrode" should be enabled or disabled according to the
% state of this button
cmd = sprintf('set(handles.stim%d, ''Enable'', ''%s'');', whichone, newstate);
eval(cmd);
% "stimulate this electrode" should default to 0...
cmd = sprintf('set(handles.stim%d, ''Value'', 0);', whichone);
eval(cmd);
handles.stim(whichone) = 0;
% ...unless...
if handles.stimAll
        % Set the "stimulate this electrode" value to match
        cmd = sprintf('set(handles.stim%d, ''Value'', %d);', whichone, value);
        eval(cmd);
        % Set the bookkeeping structure
        handles.stim(whichone) = value;
end
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);



% --- Executes on button press in electrode1.
function electrode1_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode2_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode3.
function electrode3_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode4.
function electrode4_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode5.
function electrode5_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode6.
function electrode6_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode7.
function electrode7_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode8.
function electrode8_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode9.
function electrode9_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode10.
function electrode10_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode11.
function electrode11_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode12.
function electrode12_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode13.
function electrode13_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in electrode14.
function electrode14_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in electrode15.
function electrode15_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode16.
function electrode16_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);





% --- Executes on selection change in electrode.
function monitor_electrode_control_Callback(hObject, eventdata, handles)
handles.monitor_electrode = get(hObject, 'Value');
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function monitor_electrode_control_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end





% --- Executes on button press in increase.
function increase_Callback(hObject, eventdata, handles)
disable_controls(hObject, handles);
if ~isempty(handles.timer)
        stop(handles.timer);
        delete(handles.timer);
end
global CURRENT_uAMPS;
handles.change = handles.INCREASE_STEP;
handles.timer = timer('Period', handles.INTERSPIKE_S, 'ExecutionMode', 'fixedRate');
handles.timer.TimerFcn = {@plexon_control_timer_callback, hObject, handles};
handles.timer.StartFcn = {@plexon_start_timer_callback, hObject, handles};
handles.timer.StopFcn = {@plexon_stop_timer_callback, hObject, handles};
handles.timer.ErrorFcn = {@plexon_error_timer_callback, hObject, handles};
start(handles.timer);
guidata(hObject, handles);


% --- Executes on button press in decrease.
function decrease_Callback(hObject, eventdata, handles)
disable_controls(hObject, handles);
if ~isempty(handles.timer)
        stop(handles.timer);
        delete(handles.timer);
end
global CURRENT_uAMPS;
handles.change = 1/handles.INCREASE_STEP;
handles.timer = timer('Period', handles.INTERSPIKE_S, 'ExecutionMode', 'fixedRate');
handles.timer.TimerFcn = {@plexon_control_timer_callback, hObject, handles};
handles.timer.StartFcn = {@plexon_start_timer_callback, hObject, handles};
handles.timer.StopFcn = {@plexon_stop_timer_callback, hObject, handles};
handles.timer.ErrorFcn = {@plexon_error_timer_callback, hObject, handles};
start(handles.timer);
guidata(hObject, handles);


% --- Executes on button press in hold.
function hold_Callback(hObject, eventdata, handles)
disable_controls(hObject, handles);
if ~isempty(handles.timer)
        stop(handles.timer);
        delete(handles.timer);
end
global CURRENT_uAMPS;
handles.change = 1;
handles.timer = timer('Period', handles.INTERSPIKE_S, 'ExecutionMode', 'fixedRate');
handles.timer.TimerFcn = {@plexon_control_timer_callback, hObject, handles};
handles.timer.StartFcn = {@plexon_start_timer_callback, hObject, handles};
handles.timer.StopFcn = {@plexon_stop_timer_callback, hObject, handles};
handles.timer.ErrorFcn = {@plexon_error_timer_callback, hObject, handles};
start(handles.timer);
guidata(hObject, handles);


% --- Executes on button press in stop.
function stop_Callback(hObject, eventdata, handles)
% hObject    handle to stop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
enable_controls(hObject, handles);
if ~isempty(handles.timer)
        stop(handles.timer);
        delete(handles.timer);
end
handles.timer = [];
guidata(hObject, handles);



function currentcurrent_Callback(hObject, eventdata, handles)
newcurrent = str2double(get(hObject, 'String'));
global CURRENT_uAMPS;
if isnan(newcurrent)
        set(hObject, 'String', sprintf('%3g', CURRENT_uAMPS));
elseif newcurrent < handles.START_uAMPS
        CURRENT_uAMPS = handles.START_uAMPS;
elseif newcurrent > handles.MAX_uAMPS
        CURRENT_uAMPS = handles.MAX_uAMPS;
else
        CURRENT_uAMPS = newcurrent;
end
set(hObject, 'String', sprintf('%.3g', CURRENT_uAMPS));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function currentcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function disable_controls(hObject, handles)
for i = 1:length(handles.disable_on_run)
        set(handles.disable_on_run{i}, 'Enable', 'off');
end



function enable_controls(hObject, handles)
for i = 1:length(handles.disable_on_run)
        set(handles.disable_on_run{i}, 'Enable', 'on');
end
% Yeah, but we don't want to enable all the "stim" checkboxes, but rather
% only the valid ones.  *sigh*.  They get disabled with the rest of the
% interface on start-stim, and re-enabled on stop-stim, so now let's update
% them as a special case.
for i = 1:16
        if handles.valid(i)
                status = 'on';
        else
                status = 'off';
        end
        cmd = sprintf('set(handles.stim%d, ''Enable'', ''%s'');', i, status);
        eval(cmd);
end


% When any of the "start sequence" buttons is pressed, open the Plexon box
% and do some basic error checking.
function plexon_start_timer_callback(obj, event, hObject, handles)
err = PS_InitAllStim;
switch err
    case 1
        error('plexon:init', 'Plexon initialisation error: %s', PS_GetExtendedErrorInfo(err));
    case 2
        error('plexon:init', 'Plexon: no devices available.  Is the blue box on?  Is other software accessing it?');
    otherwise
        disp('Initialised the Plexon box.');
end

try
    box = 1;
    [nchan, err] = PS_GetNChannels(box);
    if err
        ME = MException('plexon:init', 'Plexon: invalid stimulator number "%d".', box);
    else
        disp(sprintf('Plexon device %d has %d channels.', box, nchan));
    end
        box = 1;

    [nchan, err] = PS_GetNChannels(box);
    if err
        ME = MException('plexon:init', 'Plexon: invalid stimulator number "%d".', box);
    else
        disp(sprintf('Plexon device %d has %d channels.', box, nchan));
    end
    if nchan ~= 16
            ME = MException('plexon:init', 'Ben assumed that there would always be 16 channels, but there are in fact %d', nchan);
    end


    err = PS_SetTriggerMode(box, 0);
    if err
        ME = MException('plexon:stimulate', 'Could not set trigger mode on stimbox %d', box);
    end

catch ME
    disp(sprintf('Caught initialisation error %s (%s).  Shutting down...', ME.identifier, ME.message));
    report = getReport(ME)
    stop_Callback(hObject, event, handles);
    err = PS_CloseAllStim;
    rethrow(ME);
end


function plexon_stop_timer_callback(obj, event, hObject, handles)
err = PS_StopStimAllChannels(handles.box);
err = PS_CloseAllStim;


function plexon_error_timer_callback(obj, event, hObject, handles)
err = PS_StopStimAllChannels(handles.box);
err = PS_CloseAllStim;


function stim_universal_callback(hObject, eventdata, handles)
whichone = str2num(hObject.String);
handles.stim(whichone) = get(hObject, 'Value');
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);


function update_monitor_electrodes(hObject, eventdata, handles)
handles.stim
newvals = {' '};
for i = find(handles.stim)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.monitor_electrode_control, 'String', newvals);
if get(handles.monitor_electrode_control, 'Value') > length(newvals)
        set(handles.monitor_electrode_control, 'Value', 1);
end
guidata(hObject, handles);

% --- Executes on button press in stim1.
function stim1_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim2.
function stim2_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim3.
function stim3_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

function stim4_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim5.
function stim5_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim6.
function stim6_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim7.
function stim7_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim8.
function stim8_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim9.
function stim9_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim10.
function stim10_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim11.
function stim11_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim15.
function stim15_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim16.
function stim16_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim14.
function stim14_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim12.
function stim12_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim13.
function stim13_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim_all.
function stim_all_Callback(hObject, eventdata, handles)
handles.stimAll = get(hObject, 'Value');
if handles.stimAll
        for i = find(handles.valid)
                cmd = sprintf('set(handles.stim%d, ''Value'', 1);', i);
                eval(cmd);
                handles.stim(i) = 1;
        end
end
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);