# Define the needed user actions
  
"""
Actions before starting the run
- stores the particle type and initial kinetic energy 
  of the generated primary particle

"""
function beginrun!(run::G4Run, app::G4JLApplication)::Nothing
    data = getSIMdata(app)
    gun = app.generator.data.gun
    data.fParticle = gun |> GetParticleDefinition |> GetParticleName |> String
    data.fEkin = gun |> GetParticleEnergy
    return
end


"""
Actions before starting the event
- Clear the trigger and the list of tracks for the current event

"""
function beginevent!(::G4Event, app::G4JLApplication)::Nothing
    data = getSIMdata(app)
    data.trigger = false
    empty!(data.tracks)
    data.fEdep = 0.0
    return
end


"""
Actions at the end of the event
- Do nothing

"""
function endevent!(::G4Event, app::G4JLApplication)::Nothing
    return
end


"""
Actions before tracking
- pushes a new `Track` with the particle name, 
  charge, intial energy and initial point

"""
function pretrackaction!(track::G4Track, app::G4JLApplication)::Nothing
    data = getSIMdata(app)
    tracks = data.tracks
    p = GetPosition(track)[]
    particle = track |> GetParticleDefinition
    name = particle |> GetParticleName |> String
    charge = particle |> GetPDGCharge |> Int
    energy = track |> GetKineticEnergy
    trkid = track |> GetTrackID
    push!(tracks, Track(name, charge, energy, trkid, [], 
         [Point3{Float64}(x(p),y(p),z(p))]))
    return
end


"""
Actions at the end of tracking
- Used to set the trigger if the initial particle 
  exists the world without a sizeable interaction

"""
function posttrackaction!(track::G4Track, app::G4JLApplication)::Nothing
    data = getSIMdata(app)
    id = track |> GetTrackID
    energy = track |> GetKineticEnergy
    if id == 1 && energy > 0.99  * data.fEkin # primary particle did not losse any energy
        data.trigger = true
    end
    return
end


"""
Step actions
- Pushes points to the latest `Track` in the track list

"""
function stepaction!(step::G4Step, app::G4JLApplication)::Nothing
    data = getSIMdata(app)
    tracks = data.tracks
    solid_name = step |> GetPreStepPoint |> GetTouchable |> GetVolume |> GetName |> String 
    #println("solid name = ", solid_name)

    #process_name = step |> GetPostStepPoint |> GetProcessDefinedStep |> GetProcessName

    #println("process name = ", process_name)

    if solid_name == "CRYSTAL"
        p = GetPosition(GetPostStepPoint(step))
        edep = GetTotalEnergyDeposit(step)
        data.fEdep += edep
        push!(tracks[end].points, Point3{Float64}(x(p),y(p),z(p)))
        push!(tracks[end].edep, edep)
    end
    return
end