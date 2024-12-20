function pglib2excel(scenario)
dir = append('scenarios/',scenario);
mkdir(dir);
mpc_func = str2func(scenario);
mpc = mpc_func();

filename = append(dir, '/params.xlsx');

err = 0;

define_constants;
%% Scenario base configuration 
sn = mpc.baseMVA; % Base MVA for all system
if ~all(mpc.gen(:,MBASE) == sn)
    fprintf('WARNING, DIFFERENT BASE MVA DEFINED IN SCENARIO FOR GENERATORS, USING BASE %i MVA\n', sn)
end

%% Bus data creation
bus_headers = {'index', 'alias', 'slack', 'gs_mw', 'bs_mvar', 'vn_kv', 'v_pu_min', 'v_pu_max'};
% bus_i = mpc.bus(:,BUS_I) - 1;
bus_i = (0:(height(mpc.bus) - 1)).';
alias = mpc.bus(:,BUS_I);
bus_slack = zeros(height(mpc.bus), 1) + (mpc.bus(:, BUS_TYPE) == 3);
gs = mpc.bus(:,GS);
bs = mpc.bus(:,BS);
% pglib bus data structure:
%	1bus_i	2type	3Pd	4Qd	5Gs	6Bs	7area	8Vm	9Va	10baseKV	11zone	12Vmax	13Vmin
bus_data = [bus_i alias bus_slack gs bs mpc.bus(:,[BASE_KV VMIN VMAX])];

%% Generators data creation
gen_headers = {'index', 'connection1', 'p_mw_ini', 'p_mw', 'q_mvar', 'p_mw_min', 'p_mw_max', 'q_mvar_min', 'q_mvar_max', 'is_active', 'v_pu_set', 'p_c2', 'p_c1', 'q_c2', 'q_c1', 'controllable', 'priority', 'd_mw_max'};
gen_i = (0:(height(mpc.gen) - 1)).';
% gen_name = "gen" + gen_i;
gen_bus = mpc.gen(:, GEN_BUS);
% gen_bus = find(ismember(bus_name, mpc.gen(:, GEN_BUS)));
if ~all(mpc.gencost(:, MODEL) == 2)
    fprintf('ERROR, PIECEWISE COST MODEL DEFINED. THIS WORKS ONLY FOR POLYNOMIALS\n')
    err = 1;
elseif ~all(mpc.gencost(:, NCOST) <= 3)
    fprintf('ERROR, POLYNOMIALS COSTS MUST BE OF ORDER 2 OR LESS\n')
    err = 1;
else
    numgen = height(mpc.gen);
    numcosts = height(mpc.gencost);
    p_c2 = 0;
    p_c1 = 0;
    p_c0 = 0;
    q_c2 = zeros(height(mpc.gen), 1);
    q_c1 = zeros(height(mpc.gen), 1);
    q_c0 = zeros(height(mpc.gen), 1);
    if any(mpc.gencost(1:numgen, NCOST) == 3)
        p_c2 = (mpc.gencost(1:numgen, NCOST) == 3).*mpc.gencost(1:numgen, 5);
        p_c1 = (mpc.gencost(1:numgen, NCOST) == 3).*mpc.gencost(1:numgen, 6); 
        p_c0 = (mpc.gencost(1:numgen, NCOST) == 3).*mpc.gencost(1:numgen, 7); 
        if numcosts > numgen
            q_c2 = (mpc.gencost((numgen+1):numcosts, NCOST) == 3).*mpc.gencost((numgen+1):numcosts, 5);
            q_c1 = (mpc.gencost((numgen+1):numcosts, NCOST) == 3).*mpc.gencost((numgen+1):numcosts, 6); 
            q_c0 = (mpc.gencost((numgen+1):numcosts, NCOST) == 3).*mpc.gencost((numgen+1):numcosts, 7);
        end
    end
    if any(mpc.gencost(1:numgen, NCOST) == 2)
        p_c2 = p_c2 * mpc.gencost(1:numgen, 5);
        p_c1 = p_c1 + (mpc.gencost(1:numgen, NCOST) == 2).*mpc.gencost(1:numgen, 5);
        p_c0 = p_c0 + (mpc.gencost(1:numgen, NCOST) == 2).*mpc.gencost(1:numgen, 6); 
        if numcosts > numgen
            q_c2 = q_c2 * mpc.gencost((numgen+1):numcosts, 5);
            q_c1 = q_c1 + (mpc.gencost((numgen+1):numcosts, NCOST) == 2).*mpc.gencost((numgen+1):numcosts, 5);
            q_c0 = q_c0 + (mpc.gencost((numgen+1):numcosts, NCOST) == 2).*mpc.gencost((numgen+1):numcosts, 6);
        end
    end
    if any(mpc.gencost(1:numgen, NCOST) == 1)
        p_c2 = p_c2 * mpc.gencost(1:numgen, 5);
        p_c1 = p_c1 * mpc.gencost(1:numgen, 5);
        p_c0 = p_c0 + (mpc.gencost(1:numgen, NCOST) == 1).*mpc.gencost(1:numgen, 5);
        if numcosts > numgen
            q_c2 = q_c2 * mpc.gencost((numgen+1):numcosts, 5);
            q_c1 = q_c1 * mpc.gencost((numgen+1):numcosts, 5);
            q_c0 = q_c0 + (mpc.gencost((numgen+1):numcosts, NCOST) == 1).*mpc.gencost((numgen+1):numcosts, 5);
        end
    end
    if any(p_c0)  || any(q_c0)
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
controllable = ones(height(mpc.gen), 1); % By default all generators are controllable
priority = ones(height(mpc.gen), 1); % By default all generators have priority 1
d_mw_max = ones(height(mpc.gen), 1) * max(mpc.gen(:, PMAX))*10; % By default ramps are not constraints
% pglib gen data structure:
%	1bus	2Pg	3Qg	4Qmax	5Qmin	6Vg	7mBase	8status	9Pmax	10Pmin
gen_data = [gen_i gen_bus p_mw_ini mpc.gen(:,[PG QG PMIN PMAX QMIN QMAX GEN_STATUS]) v_set p_c2 p_c1 q_c2 q_c1 controllable priority d_mw_max];

%% Loads data creation
load_headers = {'index', 'connection1', 'is_active', 'controllable', 'priority', 'p_mw', 'q_mvar'};
%load_i = (0:(sum(mpc.bus(:, PD) ~= 0) - 1)).';
load_i = (0:(sum(mpc.bus(:, PD) + mpc.bus(:, QD) ~= 0) - 1)).';
% load_name = "lcrit" + load_i;
load_bus = ((mpc.bus(:, PD) + mpc.bus(:, QD) ~= 0).*mpc.bus(:, BUS_I));
load_bus(load_bus == 0) = [];
is_active = ones(height(load_i), 1); % By default all loads are active
controllable = zeros(height(load_i), 1); % By default there are no loads controllable
priority = ones(height(load_i), 1); % By default all loads have priority 1
p_mw_temp = mpc.bus(:, PD);
q_mvar_temp = mpc.bus(:, QD);
p_mw = p_mw_temp;
q_mvar = q_mvar_temp;
p_mw((p_mw_temp + q_mvar_temp) == 0) = [];
q_mvar(p_mw_temp + q_mvar_temp == 0) = [];
load_data = [load_i load_bus is_active controllable priority -p_mw -q_mvar];

%% Branchs data creation
line_headers = {'index', 'from_node', 'to_node', 's_mva_max', 'is_active', 'r_ohm', 'x_ohm', 'b_c_mho', 'tap_ratio_from', 'phase_shift_from', 'tap_ratio_to', 'phase_shift_to', 'ang_grad_min', 'ang_grad_max', 'overload_pu'};
line_i = (0:(height(mpc.branch) - 1)).';
% line_name = "line" + line_i;
from_bus = mpc.branch(:, F_BUS);
to_bus = mpc.branch(:, T_BUS);
s_max = mpc.branch(:, RATE_A) + (mpc.branch(:, RATE_A)==0)*max(mpc.branch(:, RATE_A))*1000;
v_kv = mpc.bus((to_bus), BASE_KV);
r = mpc.branch(:, BR_R).*v_kv.*v_kv/sn;
x = mpc.branch(:, BR_X).*v_kv.*v_kv/sn;
% g_sh = line_i * 0;
%g_sh = mpc.branch(:, BR_G).*v_kv.*v_kv/sn
b_c = mpc.branch(:, BR_B)./v_kv./v_kv*sn;
tap_f = mpc.branch(:, TAP) + (mpc.branch(:, TAP)==0);
shift_f = mpc.branch(:, SHIFT);
tap_t = ones(height(line_i), 1);
shift_t = zeros(height(line_i), 1);
overload_pu = ones(height(line_i), 1)*0.8; % By default 0.8
% pglib branch data structure
%	1fbus	2tbus	3r	4x	5b	6rateA	7rateB	8rateC	9ratio	10angle	11status	12angmin	13angmax
line_data = [line_i from_bus to_bus s_max mpc.branch(:,BR_STATUS) r x b_c tap_f shift_f tap_t shift_t mpc.branch(:, [ANGMIN ANGMAX]) overload_pu];


%% Excel creation 
if err == 0
    % writecell(config_headers,filename,'Sheet','config');
    % writecell(config_data,filename,'Sheet','config','Range','A2');
    
    writecell(bus_headers,filename,'Sheet','Bus');
    writematrix(bus_data,filename,'Sheet','Bus','Range','A2');
    
    writecell(line_headers,filename,'Sheet','Line');
    writematrix(line_data,filename,'Sheet','Line','Range','A2');
    
    writecell(gen_headers,filename,'Sheet','Generator');
    writematrix(gen_data,filename,'Sheet','Generator','Range','A2');
    
    writecell(load_headers,filename,'Sheet','ElectricLoad');
    writematrix(load_data,filename,'Sheet','ElectricLoad','Range','A2');
    
    fprintf('EXCEL FILE %s SUCCESSFULY CREATED\n', filename)
else
    fprintf('EXCEL NOT CREATED\n')
end

end


