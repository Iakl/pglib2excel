clear;
clc;

scenario = 'case5';
dir = append('scenarios/',scenario);
mkdir(dir);
mpc_func = str2func(scenario);
mpc = mpc_func();

filename = append(dir, '/params.xlsx');

err = 0;

define_constants;

%% Scenario base configuration 
config_headers = {'nper', 'pdur', 'sn_mva'};
nper = 1; % By default, 1 period
pdur = 60; % By default, 60 minutes of period duration
sn = mpc.baseMVA; % Base MVA for all system
if ~all(mpc.gen(:,MBASE) == sn)
    fprintf('WARNING, DIFFERENT BASE MVA DEFINED IN SCENARIO FOR GENERATORS, USING BASE %i MVA\n', sn)
end
config_data = {nper, pdur, sn};

%% Bus data creation
bus_headers = {'index', 'slack', 'gs_mw', 'bs_mvar', 'vn_kv', 'v_pu_min', 'v_pu_max'};
bus_i = mpc.bus(:,BUS_I) - 1;
% bus_name = "bus" + bus_i;
bus_slack = zeros(height(mpc.bus), 1) + (mpc.bus(:, BUS_TYPE) == 3);
% bus_vn_kv = contains(mpc.bus_name,'HV')*135 + contains(mpc.bus_name,'LV')*0.208 + contains(mpc.bus_name,'ZV')*14 + contains(mpc.bus_name,'TV')*12;
% gs_mw = -mpc.bus(:,5);
% bs_mvar = -mpc.bus(:,6);
gs_mw = zeros(height(mpc.bus), 1);
bs_mvar = zeros(height(mpc.bus), 1);
% pglib bus data structure:
%	1bus_i	2type	3Pd	4Qd	5Gs	6Bs	7area	8Vm	9Va	10baseKV	11zone	12Vmax	13Vmin
bus_data = [bus_i bus_slack mpc.bus(:,[GS BS BASE_KV VMIN VMAX])];

%% Generators data creation
gen_headers = {'index', 'bus', 'p_mw_ini', 'p_mw', 'q_mvar', 'p_mw_min', 'p_mw_max', 'q_mvar_min', 'q_mvar_max', 'is_active', 'v_pu_set', 'c2', 'c1', 'price_mode', 'controllable', 'priority', 's_max_mode', 'd_mw_max'};
gen_i = (0:(height(mpc.gen) - 1)).';
% gen_name = "gen" + gen_i;
gen_bus = mpc.gen(:, GEN_BUS) - 1;
if ~all(mpc.gencost(:, MODEL) == 2)
    fprintf('ERROR, PIECEWISE COST MODEL DEFINED. THIS WORKS ONLY FOR POLYNOMIALS\n')
    err = 1;
elseif ~all(mpc.gencost(:, NCOST) <= 3)
    fprintf('ERROR, POLYNOMIALS COSTS MUST BE OF ORDER 2 OR LESS\n')
    err = 1;
else
    c_2 = 0;
    c_1 = 0;
    c_0 = 0;
    if any(mpc.gencost(:, NCOST) == 3)
        c_2 = (mpc.gencost(:, NCOST) == 3).*mpc.gencost(:, 5);
        c_1 = (mpc.gencost(:, NCOST) == 3).*mpc.gencost(:, 6); 
        c_0 = (mpc.gencost(:, NCOST) == 3).*mpc.gencost(:, 7); 
    end
    if any(mpc.gencost(:, NCOST) == 2)
        c_2 = c_2 * mpc.gencost(:, 5);
        c_1 = c_1 + (mpc.gencost(:, NCOST) == 2).*mpc.gencost(:, 5);
        c_0 = c_0 + (mpc.gencost(:, NCOST) == 2).*mpc.gencost(:, 6); 
    end
    if any(mpc.gencost(:, NCOST) == 1)
        c_2 = c_2 * mpc.gencost(:, 5);
        c_1 = c_1 * mpc.gencost(:, 5);
        c_0 = c_0 + (mpc.gencost(:, NCOST) == 1).*mpc.gencost(:, 5);
    end
    if any(c_0)
        fprintf('WARNING, FIXED GENERATOR COST NOT IMPLEMENTED YET\n')
    end        
end
if ~all(mpc.gencost(:, STARTUP)) == 0
    fprintf('ERROR, STARTUP COST DIFFERENT FROM 0. THIS WORKS ONLY FOR 0 STARTUP COST\n')
    err = 1;
end    
if ~all(mpc.gencost(:, SHUTDOWN)) == 0
    fprintf('ERROR, SHUTDOWN COST DIFFERENT FROM 0. THIS WORKS ONLY FOR 0 SHUTDOWN COST\n')
    err = 1;
end
slack_i = find(mpc.bus(:,BUS_TYPE)==3);
if height(slack_i) > 1
    fprintf('ERROR, THERE IS MORE THAN ONE SLACK BUS\n')
    err = 1;
end
p_mw_ini = zeros(height(mpc.gen), 1); % All generators start at P = 0 by default
v_set = zeros(height(mpc.gen), 1) + (mpc.gen(:, GEN_BUS)==slack_i).*mpc.gen(:,VG); % By default generators doesnt fix voltage magnitude (assumes opf.use_vg = 0 in matpower)
price_mode = "fixed" + strings(height(mpc.gen), 1); % By default all generators use fixed costs
controllable = ones(height(mpc.gen), 1); % By default all generators are controllable
priority = ones(height(mpc.gen), 1); % By default all generators have priority 1
s_max_mode = "fixed" + strings(height(mpc.gen), 1); % By default all generators use fixed maximum
d_mw_max = ones(height(mpc.gen), 1) * max(mpc.gen(:, PMAX))*10; % By default ramps are not constraints
% pglib gen data structure:
%	1bus	2Pg	3Qg	4Qmax	5Qmin	6Vg	7mBase	8status	9Pmax	10Pmin
gen_data = [gen_i gen_bus p_mw_ini mpc.gen(:,[PG QG PMIN PMAX QMIN QMAX GEN_STATUS]) v_set c_2 c_1 price_mode controllable priority s_max_mode d_mw_max];

%% Loads data creation
load_headers = {'index', 'bus', 'load_type', 'is_active', 'controllable', 'priority', 'p_mw', 'q_mvar', 's_mode', 'p_mw_max', 'p_mw_min', 'q_mvar_max', 'q_mvar_min', 'flex_price_down', 'flex_price_up', 'flex_price_mode'};
%load_i = (0:(sum(mpc.bus(:, PD) ~= 0) - 1)).';
load_i = (0:(sum(mpc.bus(:, PD) + mpc.bus(:, QD) ~= 0) - 1)).';
% load_name = "lcrit" + load_i;
load_bus = ((mpc.bus(:, PD) + mpc.bus(:, QD) ~= 0).*mpc.bus(:, BUS_I));
load_bus(load_bus == 0) = [];
load_bus = load_bus -1;
load_type = "critical" + strings(height(load_i), 1); % By default all loads are critical
is_active = ones(height(load_i), 1); % By default all loads are active
controllable = zeros(height(load_i), 1); % By default there are no loads controllable
priority = ones(height(load_i), 1); % By default all loads have priority 1
p_mw_temp = mpc.bus(:, PD);
q_mvar_temp = mpc.bus(:, QD);
p_mw = p_mw_temp;
q_mvar = q_mvar_temp;
p_mw((p_mw_temp + q_mvar_temp) == 0) = [];
q_mvar(p_mw_temp + q_mvar_temp == 0) = [];
s_mode = "fixed" + strings(height(load_i), 1); % By default all loads use fixed demand
p_mw_max = zeros(height(load_i), 1); % By default 0
p_mw_min = zeros(height(load_i), 1); % By default 0
q_mvar_max = zeros(height(load_i), 1); % By default 0
q_mvar_min = zeros(height(load_i), 1); % By default 0
flex_price_down = zeros(height(load_i), 1); % By default 0
flex_price_up = zeros(height(load_i), 1); % By default 0
flex_price_mode = "fixed" + strings(height(load_i), 1); % By default fixed
load_data = [load_i load_bus load_type is_active controllable priority -p_mw -q_mvar s_mode -p_mw_max -p_mw_min -q_mvar_max -q_mvar_min	flex_price_down flex_price_up flex_price_mode];

%% Branchs data creation
line_headers = {'index', 'from_bus', 'to_bus', 's_mva_max', 'is_active', 'r', 'x', 'g_sh', 'b_sh', 'ang_grad_min', 'ang_grad_max', 'overload_pu'};
line_i = (0:(height(mpc.branch) - 1)).';
% line_name = "line" + line_i;
from_bus = mpc.branch(:, F_BUS) - 1;
to_bus = mpc.branch(:, T_BUS) - 1;
s_max = mpc.branch(:, RATE_A) + (mpc.branch(:, RATE_A)==0)*1000;
v_kv = mpc.bus((from_bus + 1), BASE_KV);
r = mpc.branch(:, BR_R).*v_kv.*v_kv/sn;
x = mpc.branch(:, BR_X).*v_kv.*v_kv/sn;
g_sh = line_i * 0;
%g_sh = mpc.branch(:, BR_G).*v_kv.*v_kv/sn
b_sh = mpc.branch(:, BR_B).*v_kv.*v_kv/sn;
overload_pu = ones(height(line_i), 1)*0.8; % By default 0.8
% pglib branch data structure
%	1fbus	2tbus	3r	4x	5b	6rateA	7rateB	8rateC	9ratio	10angle	11status	12angmin	13angmax
line_data = [line_i from_bus to_bus s_max mpc.branch(:,BR_STATUS) r x g_sh b_sh mpc.branch(:, [ANGMIN ANGMAX]) overload_pu];


%% Excel creation 
if err == 0
    writecell(config_headers,filename,'Sheet','config');
    writecell(config_data,filename,'Sheet','config','Range','A2');
    
    writecell(bus_headers,filename,'Sheet','Bus');
    writematrix(bus_data,filename,'Sheet','Bus','Range','A2');
    
    writecell(line_headers,filename,'Sheet','Line');
    writematrix(line_data,filename,'Sheet','Line','Range','A2');
    
    writecell(gen_headers,filename,'Sheet','Generator');
    writematrix(gen_data,filename,'Sheet','Generator','Range','A2');
    
    writecell(load_headers,filename,'Sheet','Load');
    writematrix(load_data,filename,'Sheet','Load','Range','A2');
    
    fprintf('EXCEL FILE %s SUCCESSFULY CREATED\n', filename)
else
    fprintf('EXCEL NOT CREATED\n')
end




