##############################################################################################################
# Instantiate BAU model to get some parameters and the the nice model to be used in subsequent optimizations
##############################################################################################################


# Create a folder to save results.
output_directory = joinpath((@__DIR__), "..", "..", "results", results_folder)
mkpath(output_directory)

# Load quintile income distribution scenario data.
income_distribution_raw = DataFrame(load(joinpath(@__DIR__, "..", "..", "data", quintile_income_scenario*"_quintile_distributions_consumption.csv")))

# Clean up and organize time-varying income distribution data into required NICE format (time × regions × quintiles).
income_distributions = get_quintile_income_shares(income_distribution_raw)

#---------------------------------------------------------------------------------------------------
# Create a baseline version of the model without CO₂ mitigation.
#---------------------------------------------------------------------------------------------------

# This includes the user-specifications but has no CO₂ mitigation policy (will be used to calculte global CO₂ policy).
bau_model = create_nice_recycle()
n_steps   = length(dim_keys(bau_model, :time))

# Run model and extract some generic values needed to set up optimizations below.
run(bau_model)
rice_backstop_prices  = bau_model[:emissions, :pbacktime] .* 1000

# Now set user-specified parameter settings.
update_param!(bau_model, :MIU, zeros(n_steps, 12))
update_param!(bau_model, :damage_elasticity, damage_elasticity)
update_param!(bau_model, :quintile_income_shares, income_distributions)
update_param!(bau_model, :recycle_share, recycle_share)
update_param!(bau_model, :global_carbon_tax, zeros(n_steps))
update_param!(bau_model, :rho_welfare, ρ)
update_param!(bau_model, :eta_welfare, η)

# If selected, allow elasticities to be calculated for all GDP values (not just those observed in studies).
if bound_gdp_elasticity == false
    update_param!(bau_model, :min_study_gdp, 1e-10)
    update_param!(bau_model, :max_study_gdp, +Inf)
end

run(bau_model)

# Create an instance of NICE with revenue recycling.
nice = create_nice_recycle()

# Set user-specified parameter settings.
set_param!(nice, :damage_elasticity, damage_elasticity)
set_param!(nice, :quintile_income_shares, income_distributions)
set_param!(nice, :recycle_share, recycle_share)
set_param!(nice, :rho_welfare, ρ)
set_param!(nice, :eta_welfare, η)

# If selected, allow elasticities to be calculated for all GDP values (not just those observed in studies).
if bound_gdp_elasticity == false
    set_param!(nice, :min_study_gdp, 1e-10)
    set_param!(nice, :max_study_gdp, +Inf)
end