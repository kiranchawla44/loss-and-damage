@defcomp nice_recycle begin

    # --------------------
    # Model Indices
    # --------------------

    regions                  = Index()                                     # Index for RICE regions.
    quintiles                = Index()                                     # Index for regional income quintiles.

    # --------------------
    # Model Parameters
    # --------------------

    min_study_gdp            = Parameter()                                 # Minimum observed per capita GDP value found in elasticity studies ($/person).
    max_study_gdp            = Parameter()                                 # Maximum observed per capita GDP value found in elasticity studies ($/person).
    elasticity_intercept     = Parameter()                                 # Intercept term to estimate time-varying income elasticity.
    elasticity_slope         = Parameter()                                 # Slope term to estimate time-varying income elasticity.
    damage_elasticity        = Parameter()                                 # Income elasticity of climate damages (1 = proportional to income)
    lost_revenue_share       = Parameter()                                 # Share of carbon tax revenue that is lost and cannot be recycled (1 = 100% of revenue lost, 0 = nothing lost)
    global_carbon_tax        = Parameter(index=[time])                     # Carbon tax ($/ton CO₂).
    global_recycle_share     = Parameter(index=[regions])                  # Shares of regional revenues that are recycled globally as international transfers (1 = 100% of revenue recycled globally).
    regional_population      = Parameter(index=[time, regions])            # Regional population levels (millions of people).
    DAMFRAC                  = Parameter(index=[time, regions])            # Climate damages as share of gross output.
    industrial_emissions     = Parameter(index=[time, regions])            # Industrial carbon emissions (GtC yr⁻¹).
    recycle_share            = Parameter(index=[regions, quintiles])       # Share of carbon tax revenue recycled back to each quintile.
    quintile_income_shares   = Parameter(index=[time, regions, quintiles]) # Quintile share of regional income (can vary over time).
    #for loss and damages
    DAMAGES                  = Parameter(index=[time, regions])            # Climate damages in trillions 2005$
    YGROSS          = Parameter(index=[time, regions])           # Gross economic output (trillions 2005 USD yr⁻¹).
    ABATECOST       = Parameter(index=[time, regions])           # Cost of CO₂ emission reductions (trillions 2005 USD yr⁻¹).
    savings_share   = Parameter(index=[time, regions])           # Savings rate as share of gross economic output.
    regionalLandDpayment_fixed = Parameter(index=[time, regions])
 

    # --------------------
    # Model Variables
    # --------------------

    global_pc_revenue        = Variable(index=[time])                      # Per capita carbon tax revenue from globally recycled regional revenues ($1000s/person).
    pc_gdp                   = Variable(index=[time, regions])             # Per capita output net of abatement and damages (2005 USD / person).
    CO₂_income_elasticity    = Variable(index=[time, regions])             # Elasticity of CO₂ price exposure with respect to income.
    tax_revenue              = Variable(index=[time, regions])             # Total carbon tax revenue (2005 USD).
    regional_pc_revenue      = Variable(index=[time, regions])             # Total per capita carbon tax revenue, including any international transfers ($1000s/person).
    damage_dist              = Variable(index=[time, regions, quintiles])  # Quintile share of regional climate damages (can vary over time).
    abatement_cost_dist      = Variable(index=[time, regions, quintiles])  # Time-varying regional CO₂ tax distribution share by quintile.
    carbon_tax_dist          = Variable(index=[time, regions, quintiles])  # Time-varying regional CO₂ abatement cost distribution share by quintile.
    qc_base                  = Variable(index=[time, regions, quintiles])  # Pre-damage, pre-abatement cost, pre-tax quintile consumption (thousands 2005 USD yr⁻¹).
    qc_post_damage_abatement = Variable(index=[time, regions, quintiles])  # Post-damage, post-abatement cost per capita quintile consumption (thousands 2005 USD/person yr⁻¹).
    qc_post_tax              = Variable(index=[time, regions, quintiles])  # Quintile per capita consumption after subtracting out carbon tax (thousands 2005 USD/person yr⁻¹).
    qc_post_recycle          = Variable(index=[time, regions, quintiles])  # Quintile per capita consumption after recycling tax back to quintiles (thousands 2005 USD/person yr⁻¹).
    
    
    #for loss and damages
    I               = Variable(index=[time, regions])            # Investment (trillions 2005 USD yr⁻¹).
    C               = Variable(index=[time, regions])            # Regional consumption (trillions 2005 US dollars yr⁻¹).
    CPC             = Variable(index=[time, regions])            # Regional per capita consumption (thousands 2005 USD yr⁻¹)
    Y               = Variable(index=[time, regions])            # Gross world product net of abatement and damages (trillions 2005 USD yr⁻¹).
    ABATEFRAC       = Variable(index=[time, regions])            # Cost of CO₂ emission reductions as share of gross economic output.
    #L&D calc components
    emissionsshare  = Variable(index=[time, regions])
    damagesshare    = Variable(index=[time, regions])
    regionalLandDpayment = Variable(index=[time, regions])

    
    
    function run_timestep(p, v, d, t)

        for r in d.regions

            # MimiRICE2010 calculates abatement cost in dollars. Divide by YGROSS to get abatement as share of output.
            v.ABATEFRAC[t,r] = p.ABATECOST[t,r] ./ p.YGROSS[t,r]
            
            #Add L&D calcs here
            v.emissionsshare[t,r] = p.industrial_emissions[t,r]./sum(p.industrial_emissions[t,:])
            v.damagesshare[t,r] = p.DAMAGES[t,r] ./ sum(p.DAMAGES[t,:])
            v.regionalLandDpayment[t,r] = (v.emissionsshare[t,r] - v.damagesshare[t,r]) .* p.DAMAGES[t,r]


            # Calculate net economic output following Equation 2 in Dennig et al. (PNAS 2015).
            v.Y[t,r] = (1.0 - v.ABATEFRAC[t,r]) / (1.0 + p.DAMFRAC[t,r]) * p.YGROSS[t,r] - p.regionalLandDpayment_fixed[t,r]

            # Investment.
            v.I[t,r] = p.savings_share[t,r] * v.Y[t,r]

            # Regional consumption (RICE assumes no investment in final period).
            if t.t != 60
                v.C[t,r] = v.Y[t,r] - v.I[t,r]
            else
                v.C[t,r] = v.C[t-1, r]
            end

            # Regional per capita consumption.
            v.CPC[t,r] = 1000 * v.C[t,r] / p.regional_population[t,r]

        end

        for r in d.regions

            # Calculate net per capita income ($/person).
            # Note, Y in $trillions and population in millions, so scale by 1e6.
            v.pc_gdp[t,r] = (v.Y[t,r] + p.regionalLandDpayment_fixed[t,r])/ p.regional_population[t,r] * 1e6

            # Calculate time-varying income elasticity of CO₂ price exposure (requires pc_gdp units in $/person).
            # Note, hold elasticity constant at boundary value if GDP falls outside the study support range.

            if v.pc_gdp[t,r] < p.min_study_gdp
                # GDP below observed study values.
                v.CO₂_income_elasticity[t,r] = p.elasticity_intercept + p.elasticity_slope * log(p.min_study_gdp)
            elseif v.pc_gdp[t,r] > p.max_study_gdp
                # GDP above observed study values.
                v.CO₂_income_elasticity[t,r] = p.elasticity_intercept + p.elasticity_slope * log(p.max_study_gdp)
            else
                # GDP within observed study values.
                v.CO₂_income_elasticity[t,r] = p.elasticity_intercept + p.elasticity_slope * log(v.pc_gdp[t,r])
            end

            # Calculate total carbon tax revenue for each region (dollars).
            # Note, emissions in GtC and tax in dollars, so scale by 1e9.
            v.tax_revenue[t,r] = (p.industrial_emissions[t,r] * p.global_carbon_tax[t] * 1e9) * (1.0 - p.lost_revenue_share)
        end

        # Calculate per capita tax revenue from globally recycled revenue (convert to $1000s/person to match pc consumption units).
        # Note, tax in dollars and population in millions, so scale by 1e9.
        v.global_pc_revenue[t] = sum(v.tax_revenue[t,:] .* p.global_recycle_share[:]) / sum(p.regional_population[t,:]) / 1e9

        for r in d.regions

            # Calculate total recycled per capita tax revenue for each region (this also includes the globally recycled revenue).
            v.regional_pc_revenue[t,r] = (((v.tax_revenue[t,r] * (1-p.global_recycle_share[r])) / (p.regional_population[t,r] .* 1e6)) ./ 1e3) + v.global_pc_revenue[t]

            # Calculate quintile distribution shares of CO₂ tax burden and mitigation costs (assume both distributions are equal) and cliamte damages.
            v.abatement_cost_dist[t,r,:] = regional_quintile_distribution(v.CO₂_income_elasticity[t,r], p.quintile_income_shares[t,r,:])
            v.carbon_tax_dist[t,r,:]     = regional_quintile_distribution(v.CO₂_income_elasticity[t,r], p.quintile_income_shares[t,r,:])
            v.damage_dist[t,r,:]         = regional_quintile_distribution(p.damage_elasticity, p.quintile_income_shares[t,r,:])

            # Create a temporary variable used to calculate NICE baseline quintile consumption (just for convenience).
            temp_C = (((p.YGROSS[t,r] - v.I[t,r] - p.regionalLandDpayment_fixed[t,r]) .* 1e12) ./ (p.regional_population[t,r] .* 1e6)) ./ 1e3
            temp_damagespc = ((p.DAMAGES[t,r] * 1e12) ./ (p.regional_population[t,r] .* 1e6)) ./ 1e3
            temp_abatementcost_pc = ((p.ABATECOST[t,r] * 1e12) ./ (p.regional_population[t,r] .* 1e6)) ./ 1e3

            for q in d.quintiles

                # Calculate pre-damage, pre-abatement cost quintile consumption.
                v.qc_base[t,r,q] = temp_C * p.quintile_income_shares[t,r,q]

                # Calculate post-damage, post-abatement cost per capita quintile consumption (bounded below to ensure consumptions don't collapse to zero or go negative).
                # Note, this differs from standard NICE equation because quintile CO₂ abatement cost and climate damage shares can now vary over time.
                v.qc_post_damage_abatement[t,r,q] = max(v.qc_base[t,r,q] - (temp_damagespc * v.damage_dist[t,r,q]) - (temp_abatementcost_pc * v.abatement_cost_dist[t,r,q]), 1e-8)

                # Subtract tax revenue from each quintile based on quintile CO₂ tax burden distributions.
                # Note, per capita tax revenue and consumption should both be in 1000s dollars/person.
                # turn off rev rec v.qc_post_tax[t,r,q] = v.qc_post_damage_abatement[t,r,q] - (v.regional_pc_revenue[t,r] * v.carbon_tax_dist[t,r,q])

                # Recycle tax revenue by adding shares back to all quintiles (assume recycling shares constant over time).
                #turn off rev recycling v.qc_post_recycle[t,r,q] = v.qc_post_tax[t,r,q] + (v.regional_pc_revenue[t,r] * p.recycle_share[r,q])
                v.qc_post_recycle[t,r,q] = v.qc_post_damage_abatement[t,r,q]
            end
        end
    end
end
