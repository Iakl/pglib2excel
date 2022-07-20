% load patients.mat
% T = table(LastName,Age,Weight,Smoker);
% T(1:5,:)
% filename = 'patientdata.xlsx';
% writetable(T,filename,'Sheet',1,'Range','D1')
% writetable(T,filename,'Sheet','MyNewSheet','WriteVariableNames',false);

% A = magic(5)
% C = {'Time', 'Temp'; 12 98; 13 'x'; 14 97}
% filename = 'testdata.xlsx';
% writematrix(A,filename,'Sheet',1,'Range','E1:I5')
% writecell(C,filename,'Sheet','Temperatures','Range','B2');

mpc = loadcase('case30');
filename = 'case.xlsx';

bus_headers = {'index',	'name', 'vn_kv', 'slack', 'v_pu_min', 'v_pu_max'};
writecell(bus_headers,filename,'Sheet','Bus');

%	bus_i	type	Pd	Qd	Gs	Bs	area	Vm	Va	baseKV	zone	Vmax	Vmin
writematrix(mpc.bus(:,[1 10 13 12]),filename,'Sheet','Bus','Range','A2');







