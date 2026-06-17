# S-FJSP: Sustainable Multi-Objective Flexible Job Shop Scheduling

S-FJSP is a Mixed-Integer Linear Programming (MILP) software developed in GAMS for solving the sustainable Multi-objective Flexible Job Shop Scheduling Problem. The script simultaneously optimizes makespan and energy consumption while integrating ergonomic constraints for worker physical load capacity (compliant with OCRA index and ISO 11228-1:2021), material recyclability, and carbon footprint quantification.

This repository contains the source code associated with the Original Software Publication in *SoftwareX*.

## Repository Structure
- `src/`: Contains the main GAMS script (`FJSPv3_English.gms`).
- `LICENSE.txt`: MIT License terms.
- `README.md`: This documentation file.

## Requirements
To compile and execute this software, the following environment is required:
- **GAMS System:** GAMS Studio (version 48.3 or higher recommended).
- **Solver:** A licensed MILP solver, such as IBM ILOG CPLEX (default in the script) or Gurobi.
- **Operating System:** Windows, macOS, or Linux compatible with GAMS.

## How to Run
1. Clone or download this repository to your local machine.
2. Open the `FJSPv3_English.gms` file located in the `src/` directory using GAMS Studio.
3. Configure the optimization parameters in the *MODE AND OPTIMIZATION METHOD CONTROL* section of the code:
   - Set `SUSTAINABLE_MODE = 1` for bi-objective optimization.
   - Set `GENERATE_PARETO = 1` to generate the Pareto frontier.
4. Run the script. 
5. The optimization outputs will be displayed in the compilation log, and three CSV files (`individual_result.csv`, `pareto_frontier.csv`, and `detailed_assignments.csv`) will be automatically generated in your working directory.

## Authors
- Israel D. Herrera-Granda (Universidad Politécnica Estatal del Carchi / Universitat Politècnica de València)

## Acknowledgements
This software was developed with the support of Universidad Politécnica Estatal del Carchi (UPEC), Tulcán-Ecuador, through funds allocated to the research project "Modelos De Optimización De Operaciones De La Cadena De Suministro" (Code: DIIN-2026-09).

## License
This project is licensed under the MIT License - see the `LICENSE.txt` file for details.
