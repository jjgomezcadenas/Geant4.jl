#---Define Simulation Data struct------------------------------------------------------------------
struct Track
    particle::String
    charge::Int
    energy::Float64
    trkid::Int
    edep::Vector{Float64}
    points::Vector{Point3{Float64}}
end

mutable struct CrstSimData <: G4JLSimulationData
    #---Run data-----------------------------------------------------------------------------------
    fParticle::String
    fEkin::Float64
    fEdep::Float64
    #---trigger-------------------------------------------------------------------------------
    trigger::Bool
    #---tracks-------------------------------------------------------------------------------------
    tracks::Vector{Track}
    CrstSimData() = new("", 0.0, 0.0, false, [])
end