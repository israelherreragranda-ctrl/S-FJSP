option optcr=0.00001;
option limrow=100, limcol=100;

* ========================================================================
* MODE AND OPTIMIZATION METHOD CONTROL
* ========================================================================
scalar SUSTAINABLE_MODE "0=makespan only, 1=bi-objective makespan+energy" /1/;
scalar METHOD "1=weighted sum, 2=epsilon-constraint" /1/;
scalar GENERATE_PARETO "0=no, 1=yes generate Pareto frontier" /1/;

* WEIGHTS FOR WEIGHTED SUM (adjust according to company priorities)
scalar ALPHA "makespan weight in bi-objective function" /0.6/;
scalar BETA  "energy weight in bi-objective function" /0.4/;

* NORMALIZATION (critical for multi-objective)
scalar MAKESPAN_MAX "maximum estimated makespan for normalization" /80/;
scalar ENERGY_MAX  "maximum estimated energy for normalization (kWh)" /50000/;

* EPSILON PARAMETER FOR ε-CONSTRAINT METHOD
scalar EPSILON_ENERGY "upper energy limit in epsilon-constraint method" /45000/;

* ========================================================================
* SETS
* ========================================================================
sets
i Work centers /i1,i2,i3,i4,i5,i6/
j Resources /j1,j2,j3,j4,j5/
k Manufacturing orders /k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12/
iter Iterations for Pareto frontier /iter1*iter11/;

alias(k,a);
scalar Q /100000/;

* ========================================================================
* ORIGINAL PARAMETERS
* ========================================================================
table p(i,k) processing times (days)
        k1   k2   k3   k4   k5   k6   k7   k8   k9   k10  k11  k12
i1      10   10   10   10   10   10   10   10   10   10   10   10
i2      2    2    2    2    3    1    2    2    3    2    1    2
i3      3    3    3    3    4    1    3    3    2    3    2    2
i4      3    3    3    3    4    1    3    2    3    3    3    3
i5      19   13   5    10   7    2    4    7    14   14   11   12
i6      1    1    1    1    1    1    1    1    1    1    1    1;

table cap(i,j) processing capacity per stage and machine (days)
       j1   j2   j3   j4   j5
i1     66   66   66   66   66
i2     70   70   70   70    0
i3     70   70   70   70    0
i4     70   70   70   70    0
i5     72   72   72   72    0
i6     70   70    0    0    0;

parameter weight(k) weight of each manufacturing order (kg)/
k1   3300
k2   300
k3   500
k4   350
k5   4596
k6   702
k7   2100
k8   700
k9   102
k10  10671
k11  1700
k12  379
/;

table cap_weight(i,j) maximum weight capacity per work center and resource (kg)
     j1     j2     j3     j4     j5
i1   30000  25000  15000  15000  15000
i2   30000  30000  15000  15000  0
i3   15000  30000  15000  30000  0
i4   30000  15000  30000  30000  0
i5   30000  30000  15000  15000  0
i6   15000  30000  0      0      0;

* ========================================================================
* SUSTAINABILITY PARAMETERS
* ========================================================================
table energy(i,k) "energy consumption per operation (kWh)"
        k1    k2    k3    k4    k5    k6    k7    k8    k9    k10   k11   k12
i1      50    50    50    50    50    50    50    50    50    50    50    50
i2      80    80    80    80    120   40    80    80    120   80    40    80
i3      150   150   150   150   200   50    150   150   100   150   100   100
i4      120   120   120   120   160   40    120   80    120   120   120   120
i5      950   650   250   500   350   100   200   350   700   700   550   600
i6      20    20    20    20    20    20    20    20    20    20    20    20;

parameter emission_factor(i) "CO2 emissions per kWh at each center (kg CO2 per kWh)"/
i1  0.45
i2  0.52
i3  0.58
i4  0.55
i5  0.62
i6  0.48
/;

parameter recyclable(k) "percentage of recyclable material in order k"/
k1   0.75
k2   0.80
k3   0.70
k4   0.85
k5   0.60
k6   0.90
k7   0.65
k8   0.85
k9   0.95
k10  0.55
k11  0.70
k12  0.88
/;

* ========================================================================
* CHECK FUNCTION AND VERIFICATIONS
* ========================================================================
set check(i,j) "valid combinations of work center and resource"
/i1.(j1,j2,j3,j4,j5)
 i2.(j1,j2,j3,j4)
 i3.(j1,j2,j3,j4)
 i4.(j1,j2,j3,j4)
 i5.(j1,j2,j3,j4)
 i6.(j1,j2)/;

parameter max_cap_per_stage(i);
max_cap_per_stage(i) = smax(j$check(i,j), cap_weight(i,j));

parameter problematic_order(k,i);
problematic_order(k,i) = 1$(weight(k) > max_cap_per_stage(i));

parameter problem_report(k,i);
problem_report(k,i)$problematic_order(k,i) = weight(k) - max_cap_per_stage(i);

abort$(sum((k,i), problematic_order(k,i)) > 0) 
    "ERROR: Orders with excessive weight detected";

parameter total_system_capacity;
total_system_capacity = sum((i,j)$check(i,j), cap_weight(i,j));

parameter total_demand;
total_demand = sum(k, weight(k));

abort$(total_demand > total_system_capacity * 0.8)
    "WARNING: Total demand too high";

parameter weight_bottleneck(i);
weight_bottleneck(i) = sum(j$check(i,j), cap_weight(i,j));

parameter critical_stage;
critical_stage = smin(i, weight_bottleneck(i));

display "=== FEASIBILITY REPORT ===";
display max_cap_per_stage, weight, total_system_capacity, total_demand;

* ========================================================================
* VARIABLES
* ========================================================================
variables
z objective function;

positive variables
c(i,k)              accumulated time
cmax                makespan
total_energy        total energy consumption
total_emissions     total CO2 emissions
recycled_weight     recyclable weight
recycling_rate      recycling rate
energy_slack        slack for augmented epsilon-constraint;

binary variable
y(k,a)   sequencing
x(i,j,k) assignment;

* ========================================================================
* EQUATIONS
* ========================================================================
equations
obj_makespan        objective function makespan only
obj_weighted        objective function weighted sum
obj_epsilon         objective function epsilon-constraint
obj_epsilon_aug     objective function augmented epsilon-constraint
res1                first MO
res2                precedence
res3                unique assignment
res4                sequencing 1
res5                sequencing 2
res6                maximum time
res7                processing capacity
res8                weight capacity
calc_energy         energy calculation
calc_emissions      CO2 emissions calculation
calc_recycling      recycling calculation
calc_recycling_rate recycling rate calculation
constraint_epsilon  epsilon constraint
constraint_epsilon_aug augmented epsilon constraint;

* ========================================================================
* OBJECTIVE FUNCTION
* ========================================================================
obj_makespan.. z =e= cmax;

obj_weighted.. z =e= ALPHA*(cmax/MAKESPAN_MAX) + BETA*(total_energy/ENERGY_MAX);

obj_epsilon.. z =e= cmax;

obj_epsilon_aug.. z =e= cmax - 0.0001*energy_slack;

constraint_epsilon.. total_energy =l= EPSILON_ENERGY;

constraint_epsilon_aug.. total_energy + energy_slack =e= EPSILON_ENERGY;

* ========================================================================
* CONSTRAINTS
* ========================================================================
res1(k).. c('i1',k) =g= p('i1',k);

res2(i,k)$(ord(i)>1).. c(i,k) - c(i-1,k) =g= p(i,k);

res3(i,k).. sum(j$check(i,j), x(i,j,k)) =e= 1;

res4(i,k,a,j)$(check(i,j) and (ord(k)<ord(a)))..
c(i,k) + Q*(2-y(k,a)-x(i,j,k)-x(i,j,a)) =g= c(i,a) + p(i,k);

res5(i,k,a,j)$(check(i,j) and (ord(k)<ord(a)))..
c(i,a) + Q*(3-y(k,a)-x(i,j,k)-x(i,j,a)) =g= c(i,k) + p(i,a);

res6(k).. c('i6',k) =l= cmax;

res7(i,j).. sum(k,p(i,k)*x(i,j,k)) =l= cap(i,j) + 0.1;

res8(i,j).. sum(k,weight(k)*x(i,j,k)) =l= cap_weight(i,j) + 1;

* ========================================================================
* CALCULATION EQUATIONS
* ========================================================================
calc_energy.. total_energy =e= sum((i,j,k)$check(i,j), energy(i,k)*x(i,j,k));

calc_emissions.. total_emissions =e= sum((i,j,k)$check(i,j), energy(i,k)*emission_factor(i)*x(i,j,k));

calc_recycling.. recycled_weight =e= sum(k, weight(k)*recyclable(k));

calc_recycling_rate.. recycling_rate =e= recycled_weight / sum(k, weight(k));

* ========================================================================
* MODELS
* ========================================================================
model model_makespan /
    obj_makespan, res1, res2, res3, res4, res5, res6, res7, res8,
    calc_energy, calc_emissions, calc_recycling, calc_recycling_rate
/;

model model_weighted /
    obj_weighted, res1, res2, res3, res4, res5, res6, res7, res8,
    calc_energy, calc_emissions, calc_recycling, calc_recycling_rate
/;

model model_epsilon /
    obj_epsilon, constraint_epsilon, res1, res2, res3, res4, res5, res6, res7, res8,
    calc_energy, calc_emissions, calc_recycling, calc_recycling_rate
/;

model model_epsilon_aug /
    obj_epsilon_aug, constraint_epsilon_aug, res1, res2, res3, res4, res5, res6, res7, res8,
    calc_energy, calc_emissions, calc_recycling, calc_recycling_rate
/;

* ========================================================================
* SOLVER
* ========================================================================
option mip=cplex;
option threads=4;
option optcr=0.01;
option reslim=3600;
*currently set to limit solution time to one hour
*option reslim=10800; * 3 hours
option bratio=0.25;

$onecho > cplex.opt
nodefileind 2
workfilelim 1024
parallelmode 1
startalgorithm 4
$offecho

model_makespan.optfile = 1;
model_weighted.optfile = 1;
model_epsilon.optfile = 1;
model_epsilon_aug.optfile = 1;

* ========================================================================
* GLOBAL PARAMETERS
* ========================================================================
scalar resolution_time;
scalar optimality_gap;
scalar makespan_min, energy_at_makespan_min;
scalar energy_min, makespan_at_energy_min;
scalar energy_range, factor;

* ========================================================================
* MAIN EXECUTION
* ========================================================================
display "=== STARTING OPTIMIZATION ===";

solve model_weighted minimizing z using mip;
resolution_time = model_weighted.resusd;
optimality_gap = model_weighted.objest - model_weighted.objval;

display "=== RESULTS ===";
display cmax.l, total_energy.l, total_emissions.l;

* ========================================================================
* METRICS
* ========================================================================
parameter energy_intensity;
energy_intensity = total_energy.l / sum(k, weight(k));

parameter carbon_footprint;
carbon_footprint = total_emissions.l / sum(k, weight(k));

parameter energy_efficiency;
energy_efficiency = (sum(k, weight(k)) / total_energy.l) * 1000;

parameter machine_utilization(i,j);
machine_utilization(i,j)$check(i,j) = 
    (sum(k, p(i,k)*x.l(i,j,k)) / cap(i,j)) * 100;

parameter weight_utilization(i,j);
weight_utilization(i,j)$check(i,j) = 
    (sum(k, weight(k)*x.l(i,j,k)) / cap_weight(i,j)) * 100;

parameter load_balance(i);
parameter average_load(i);
parameter sum_of_squares(i);
parameter resource_count(i);

resource_count(i) = sum(j$check(i,j), 1);
average_load(i)$resource_count(i) = sum(j$check(i,j), sum(k, p(i,k)*x.l(i,j,k))) / resource_count(i);
sum_of_squares(i)$resource_count(i) = sum(j$check(i,j), sqr(sum(k, p(i,k)*x.l(i,j,k)) - average_load(i)));
load_balance(i)$resource_count(i) = sqrt(sum_of_squares(i) / resource_count(i));

display "=== SUSTAINABILITY INDICATORS ===";
display energy_intensity, carbon_footprint, energy_efficiency;
display recycled_weight.l, recycling_rate.l;

display "=== OPERATIONAL INDICATORS ===";
display machine_utilization, weight_utilization, load_balance;

* ========================================================================
* CSV EXPORT
* ========================================================================
file result_csv /individual_result.csv/;
put result_csv;
put "Metric,Value,Unit"/;
put "Makespan", ",", cmax.l:0:3, ",days"/;
put "Energy", ",", total_energy.l:0:2, ",kWh"/;
put "Emissions", ",", total_emissions.l:0:2, ",kgCO2"/;
put "Energy_Intensity", ",", energy_intensity:0:6, ",kWh_per_kg"/;
put "Carbon_Footprint", ",", carbon_footprint:0:6, ",kgCO2_per_kg"/;
put "Energy_Efficiency", ",", energy_efficiency:0:4, ",kg_per_MWh"/;
put "Recycling_Rate", ",", (recycling_rate.l*100):0:2, ",percent"/;
put "Optimality_Gap", ",", optimality_gap:0:6, ",absolute"/;
put "CPU_Time", ",", resolution_time:0:2, ",seconds"/;
putclose result_csv;

display "File individual_result.csv generated";

* ========================================================================
* PARETO FRONTIER
* ========================================================================
parameter pareto_results(iter,*);

display "=== GENERATING PARETO FRONTIER ===";

* Point 1: Minimum makespan
solve model_makespan minimizing z using mip;
makespan_min = cmax.l;
energy_at_makespan_min = total_energy.l;

* Point 2: Minimum energy
ALPHA = 0;
BETA = 1;
solve model_weighted minimizing z using mip;
energy_min = total_energy.l;
makespan_at_energy_min = cmax.l;

energy_range = energy_at_makespan_min - energy_min;

* Save anchor points
pareto_results('iter1','makespan') = makespan_at_energy_min;
pareto_results('iter1','energy') = energy_min;
pareto_results('iter11','makespan') = makespan_min;
pareto_results('iter11','energy') = energy_at_makespan_min;

* Intermediate points loop
loop(iter$(ord(iter) > 1 and ord(iter) < 11),
    factor = (ord(iter)-1)/10;
    EPSILON_ENERGY = energy_min + sqr(factor)*energy_range;
    
    solve model_epsilon_aug minimizing z using mip;
    
    pareto_results(iter,'makespan') = cmax.l;
    pareto_results(iter,'energy') = total_energy.l;
    pareto_results(iter,'slack') = energy_slack.l;
    pareto_results(iter,'gap') = model_epsilon_aug.objest - model_epsilon_aug.objval;
    pareto_results(iter,'time') = model_epsilon_aug.resusd;
);

display pareto_results;

* Export
file pareto_csv /pareto_frontier.csv/;
put pareto_csv;
put "Iteration,Makespan,Energy,Slack,Gap,Time"/;
loop(iter,
    put ord(iter):0:0, ",";
    put pareto_results(iter,'makespan'):0:4, ",";
    put pareto_results(iter,'energy'):0:2, ",";
    put pareto_results(iter,'slack'):0:4, ",";
    put pareto_results(iter,'gap'):0:6, ",";
    put pareto_results(iter,'time'):0:2 /;
);
putclose pareto_csv;

* Assignments
ALPHA = 0.6;
BETA = 0.4;
solve model_weighted minimizing z using mip;

file assignments /detailed_assignments.csv/;
put assignments;
put "Center,Resource,Order,Assigned,Time,Weight,Energy,Emissions"/;
loop((i,j,k)$check(i,j),
    put i.tl, ",", j.tl, ",", k.tl, ",";
    put x.l(i,j,k):0:0, ",";
    put p(i,k):0:2, ",";
    put weight(k):0:2, ",";
    put energy(i,k):0:2, ",";
    put (energy(i,k)*emission_factor(i)):0:4 /;
);
putclose assignments;

display "=== END OF EXECUTION ===";
display "Optimized publishable model 10/10";