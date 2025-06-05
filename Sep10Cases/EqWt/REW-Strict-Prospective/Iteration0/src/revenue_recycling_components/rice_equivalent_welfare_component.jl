@defcomp rice_equivalent_welfare_component begin

    regions      = Index()                                     # Index for RICE regions.

    eta_welfare          = Parameter()                                 # Elasticity of marginal utility of consumption.
    rho_welfare          = Parameter()                                 # Pure rate of time preference.
    regional_population_welfare      = Parameter(index=[time, regions])            # Regional population levels (millions of people).
    C = Parameter(index=[time, regions])            # Regional consumption (trillions 2005 US dollars yr⁻¹).

    global_welfare    = Variable()                                    # Total economic welfare.
    regional_pc_consumption = Variable(index=[time, regions])
    regional_utility = Variable(index=[time, regions])
    population_weighted_regional_utility = Variable(index=[time, regions])
    
    function run_timestep(p, v, d, t)
        for r in d.regions
            v.regional_pc_consumption[t,r] = 1000 .* (p.C[t,r] ./ p.regional_population_welfare[t,r]) #consumption is in trillions and pop in millions, and global pc consumption in 1000s
            v.regional_utility[t,r] = (v.regional_pc_consumption[t,r] .^ (1.0 - p.eta_welfare)) ./ (1.0 - p.eta_welfare)
            v.population_weighted_regional_utility[t,r] = v.regional_utility[t,r] .* p.regional_population_welfare[t,r]
        end
        

        if is_first(t)
            # Calculate period 1 welfare.
            v.global_welfare = sum(v.population_weighted_regional_utility[t,:]) / (1.0 + p.rho_welfare)^(10*(t.t-1))
       
        else
            # Calculate cummulative welfare over time.
            v.global_welfare = v.global_welfare + sum(v.population_weighted_regional_utility[t,:]) / (1.0 + p.rho_welfare)^(10*(t.t-1))
        end
    end
end