######################################################################################################################
# This file replicates the NICE model runs (with and without revenue recycling) presented in Budolfson et al. (2021),
# "Climate Action With Revenue Recycling Has Benefits For Poverty, Inequality, And Wellbeing," Nature Climate Change.
######################################################################################################################

# Activate the project for the paper and make sure all packages we need
# are installed.
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

# Load required Julia packages.
using Interpolations, MimiFAIR13, NLopt

# Load NICE+recycling source code.
include("MimiNICE_recycle_time_varying.jl")

# ------------------------------------------------------------------------------------------------
# NICE + REVENUE RECYCLING PARAMETERS TO CHANGE
# ------------------------------------------------------------------------------------------------

# Pure rate of time preference.
ρ =  0.015

# Elasticity of marginal utility of consumption.
η =  1.5

# Income elasticity of climate damages (1 = proportional to income, -1 = inversely proportional to income).
damage_elasticity = 1.0

# Share of recycled carbon tax revenue that each region-quintile pair receives (row = region, column = quintile)
recycle_share = ones(12,5) .* 0.2

# Should the time-varying elasticity values only change across the range of GDP values from the studies?
# true = limit calculations to study gdp range, false = allow calculations for 0 to +Inf GDP.
bound_gdp_elasticity = false

# Quintile income distribution scenario (options = "constant", "lessInequality", "moreInequality", "SSP1", "SSP2", "SSP3", "SSP4", or "SSP5")
quintile_income_scenario = "constant"

# Do you also want to perform a reference case optimization run (with no revenue recycling)?
run_reference_case = true

# Name of folder to store your results in (a folder will be created with this name).
results_folder = "base_case"

# run and SAVE, or just run
save_results = true

# ------------------------------------------------------------------------------------------------
# CHOICES ABOUT YOUR ANALYSIS & OPTIMZATION
# ------------------------------------------------------------------------------------------------

# Number of 10-year timesteps to find optimal carbon tax for (after which model assumes full decarbonization).
n_objectives = 45

# Global optimization algorithm (:symbol) used for initial result. See options at http://ab-initio.mit.edu/wiki/index.php/NLopt_Algorithms
global_opt_algorithm = :GN_DIRECT_L

# Local optimization algorithm (:symbol) used to "polish" global optimum solution.
local_opt_algorithm = :LN_SBPLX

# Maximum time in seconds to run global optimization (in case optimization does not converge).
global_stop_time = 600

# Maximum time in seconds to run local optimization (in case optimization does not converge).
local_stop_time = 300

# Relative tolerance criteria for global optimization convergence (will stop if |Δf| / |f| < tolerance from one iteration to the next.)
global_tolerance = 1e-8

# Relative tolerance criteria for global optimization convergence (will stop if |Δf| / |f| < tolerance from one iteration to the next.)
local_tolerance = 1e-12

# ------------------------------------------------------------------------------------------------
# RUN EVERYTHING & SAVE KEY RESULTS
# ------------------------------------------------------------------------------------------------



# ------------------------------------------------------
# ------------------------------------------------------
# Add iterative optimzation with FAIRv1.3 Climate Model
# ------------------------------------------------------
# ------------------------------------------------------

# Reset model parameters to default values.
ρ = 0.015
η = 1.5
damage_elasticity = 1.0
recycle_share = ones(12,5) .* 0.2
bound_gdp_elasticity = false
quintile_income_scenario = "constant"

# Reset optimization parameters to default values
# Note: FAIR optimziation just uses a local optimization due to computational burden of iterative approach
run_reference_case = true
n_objectives = 45
n_fair_loops = 4
local_opt_algorithm = :LN_SBPLX
local_stop_time = 800
local_tolerance = 1e-11
results_folder = "FAIR_climate_model"

# Initialize BAU and base version of NICE with revenue recucling.
include(joinpath("replication_helpers", "instantiate_model_in_interface.jl"))
include(joinpath("replication_helpers", "optimize_with_FAIR.jl"))

# Reload NICE+recycling model.
include("MimiNICE_recycle_time_varying.jl")



println("All done!")
