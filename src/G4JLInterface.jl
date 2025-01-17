#---Exports from this section----------------------------------------------------------------------
export G4JLDetector, G4JLSimulationData, G4JLApplication, G4JLDetectorGDML, G4JLSDData, G4JLSensitiveDetector, 
        configure, initialize, reinitialize, beamOn, getSDdata, getSIMdata, getConstructor, getInitializer, G4JLGunGenerator, 
        G4JLPrimaryGenerator, G4JLGeneratorData, G4JLUniformMagField, G4JLMagneticField, G4JLFieldData

#---Geometry usability functions-------------------------------------------------------------------
G4PVPlacement(r::Union{Nothing, G4RotationMatrix}, d::G4ThreeVector, l::Union{Nothing,G4LogicalVolume}, s::String, 
              p::Union{Nothing, G4LogicalVolume}, b1::Bool, n::Int, b2::Bool=false) = 
    G4PVPlacement(isnothing(r) ? CxxPtr{G4RotationMatrix}(C_NULL) : move!(r), d, 
                  isnothing(l) ? CxxPtr{G4LogicalVolume}(C_NULL) : CxxPtr(l), s, 
                  isnothing(p) ? CxxPtr{G4LogicalVolume}(C_NULL) : CxxPtr(p), b1, n, b2)

G4PVPlacement(t::G4Transform3D, l::Union{Nothing,G4LogicalVolume}, s::String, 
              p::Union{Nothing, G4LogicalVolume}, b1::Bool, n::Int, b2::Bool=false) = 
    G4PVPlacement(t, isnothing(l) ? CxxPtr{G4LogicalVolume}(C_NULL) : CxxPtr(l), s, 
                  isnothing(p) ? CxxPtr{G4LogicalVolume}(C_NULL) : CxxPtr(p), b1, n, b2)

G4PVReplica(s::String, l::G4LogicalVolume, m::G4LogicalVolume, a::EAxis, n::Int64, t::Float64) = 
    G4PVReplica(s, CxxPtr(l), CxxPtr(m), a, n, t)

function G4JLDetectorConstruction(f::Function)
    sf = make_callback(nothing, f, CxxPtr{G4VPhysicalVolume}, ()) |> closure
    G4JLDetectorConstruction(sf...)
end

function G4JLActionInitialization(f::Function)
    sf = make_callback(nothing, f, Nothing, (ConstCxxPtr{G4JLActionInitialization},)) |> closure
    G4JLActionInitialization(sf..., sf...)                          # call the construction                        
end

function G4LogicalVolume(solid::G4VSolid, mat::CxxPtr{G4Material}, name::String,
                         fldmgr=CxxPtr{G4FieldManager}(C_NULL), 
                         sd=CxxPtr{G4VSensitiveDetector}(C_NULL), 
                         ulimits=CxxPtr{G4UserLimits}(C_NULL), 
                         opt=true)
    G4LogicalVolume(move!(solid), mat, name, 
                    fldmgr isa G4FieldManagerAllocated ? move!(fldmgr) : fldmgr,
                    sd isa CxxPtr ? sd  : move!(sd),
                    ulimits isa  G4UserLimitsAllocated ? move!(ulimits) : ulimits,  opt)
end
SetUserLimits(lv::G4LogicalVolume, l::G4UserLimitsAllocated) = SetUserLimits(lv, move!(l))     

#---Material friendly functions (keyword arguments)------------------------------------------------
using .SystemOfUnits:kelvin, atmosphere
G4Material(name::String; z::Float64=0., a::Float64=0., density::Float64, ncomponents::Integer=0, 
           state::G4State=kStateUndefined, temperature::Float64=293.15*kelvin, pressure::Float64=1*atmosphere) = 
    ncomponents == 0 ? G4Material(name, z, a, density, state, temperature, pressure) : G4Material(name, density, ncomponents)
AddElement(mat::G4Material, elem::CxxPtr{G4Element}; fractionmass::Float64=0., natoms::Integer=0) = 
    fractionmass != 0. ?  AddElementByMassFraction(mat, elem, fractionmass) : AddElementByNumberOfAtoms(mat, elem, natoms)
AddMaterial(mat::G4Material, mat2::CxxPtr{G4Material}; fractionmass=1.0) = AddMaterial(mat, mat2, fractionmass)
AddMaterial(mat::G4Material, mat2::G4Material; fractionmass=1.0) = AddMaterial(mat, CxxPtr(mat2), fractionmass)
G4Isotope(name::String; z::Integer, n::Integer, a::Float64=0., mlevel::Integer=0) = G4Isotope(name, z, n, a, mlevel)

#---Better HL interface (more Julia friendly)------------------------------------------------------
abstract type  G4JLAbstrcatApp end
abstract type  G4JLDetector end
abstract type  G4JLSimulationData end
abstract type  G4JLSDData end
abstract type  G4JLGeneratorData end
abstract type  G4JLFieldData end

getConstructor(d::G4JLDetector) = error("You need to define the function Geant4.getConstructor($(typeof(d))) returning the actual contruct method")
getInitializer(::G4VUserPrimaryGeneratorAction) = nothing

#---G4JLDetectorGDML----(GDML reader)--------------------------------------------------------------
struct G4JLDetectorGDML <: G4JLDetector
    fPhysicalWorld::CxxPtr{G4VPhysicalVolume}
end
getConstructor(::G4JLDetectorGDML) = (det::G4JLDetectorGDML) -> det.fPhysicalWorld
"""
    G4JLDetectorGDML(gdmlfile::String; check_overlap::Bool)

Initialize a G4JLDetector from a GDML file. The GDML file is parsed at this moment.
"""
function G4JLDetectorGDML(gdmlfile::String; check_overlap::Bool=false)
    parser = G4GDMLParser()
    !isfile(gdmlfile) && error("GDML File $gdmlfile does not exists")
    SetOverlapCheck(parser, check_overlap)
    Read(parser, gdmlfile)
    G4JLDetectorGDML(GetWorldVolume(parser))
end

#---Primary Particle Generator----------------------------------------------------------------------
mutable struct G4JLPrimaryGenerator{UD<:G4JLGeneratorData}
    const name::String
    const data::UD
    const init_method::Function    #  (::UD, ::G4JLApplication)::Nothing
    const gen_method::Function     #  (::CxxPtr{G4Event}, ::UD)::Nothing
    base::Vector{G4JLGeneratorAction}
end
"""
    G4JLPrimaryGenerator(name::String, data::DATA; <keyword arguments>) where DATA<:G4JLGeneratorData

Creatre a G4JLPrimaryGenerator with its name and associated DATA structure
# Arguments
"""
function G4JLPrimaryGenerator(name::String, data::T;
                              init_method=nothing,
                              generate_method=nothing) where T<:G4JLGeneratorData
    isnothing(generate_method) && error("primary particle generator method not defined")
    G4JLPrimaryGenerator{T}(name, data, init_method, generate_method, G4JLGeneratorAction[])   
end

#---Implementation (user friendly) Particle Gun----------------------------------------------------
mutable struct G4JLParticleGunData <: G4JLGeneratorData
    gun::Union{Nothing, CxxPtr{G4ParticleGun}}
    particle::String
    direction::G4ThreeVector
    position::G4ThreeVector
    energy::Float64
end
function G4JLPrimaryGenerator{G4JLParticleGunData}(;particle="e-", energy=10., direction=G4ThreeVector(), position=G4ThreeVector())
    data = G4JLParticleGunData(nothing, particle, direction, position, energy)
    function init(data::G4JLParticleGunData, ::Any)
        pg = data.gun = move!(G4ParticleGun())
        SetParticleByName(pg, data.particle)
        SetParticleEnergy(pg, data.energy)
        SetParticleMomentumDirection(pg, data.direction)
        SetParticlePosition(pg, data.position)
    end
    function gen(evt::G4Event, data::G4JLParticleGunData)::Nothing
        GeneratePrimaryVertex(data.gun, CxxPtr(evt))
    end
    G4JLPrimaryGenerator("ParticleGun", data; init_method=init, generate_method=gen)
end

const G4JLGunGenerator = G4JLPrimaryGenerator{G4JLParticleGunData}

function SetParticleByName(gen::G4JLGunGenerator, particle::String)
    gen.data.particle=particle
    SetParticleByName(gen.data.gun, particle)
end
function SetParticleEnergy(gen::G4JLGunGenerator, energy::Float64)
    gen.data.energy=energy
    SetParticleEnergy(gen.data.gun, energy)
end
function SetParticleMomentumDirection(gen::G4JLGunGenerator, direction::G4ThreeVector)
    gen.data.direction=direction
    SetParticleMomentumDirection(gen.data.gun, direction)
end
function SetParticlePosition(gen::G4JLGunGenerator, position::G4ThreeVector)
    gen.data.direction=position
    SetParticlePosition(gen.data.gun, position)
end

#---Custom Magnetic Field--------------------------------------------------------------------------
mutable struct G4JLMagneticField{UD<:G4JLFieldData}
    const name::String
    const data::UD
    const getfield::Function    #  signature  (result::G4ThreeVector, position::G4ThreeVector, ::SD)
    base::Vector{G4JLMagField}
end
"""
    G4JLMagneticField(name::String, data::DATA; <keyword arguments>) where DATA<:G4JLGeneratorData

Create a G4JLMagneticField with its name and associated DATA structure
# Arguments
"""
function G4JLMagneticField(name::String, data::T;
                           getfield_method=nothing) where T<:G4JLFieldData
    isnothing(getfield_method) && error("get field method not defined")
    G4JLMagneticField{T}(name, data, getfield_method, G4JLMagField[])   
end

#---Implementation (user friendly) Uniform Magnetic Field------------------------------------------
mutable struct G4JLUniformMagFieldData <: G4JLFieldData
    field::G4ThreeVector
end

function G4JLMagneticField{G4JLUniformMagFieldData}(field::G4ThreeVector)
    data = G4JLUniformMagFieldData(field)
    function getfield!(field::G4ThreeVector, pos::G4ThreeVector, data::G4JLUniformMagFieldData)::Nothing
        assign(field, data.field)
        return
    end
    G4JLMagneticField("UnifiormB", data; getfield_method=getfield!)
end

const G4JLUniformMagField = G4JLMagneticField{G4JLUniformMagFieldData}

#---SentitiveDetectors-----------------------------------------------------------------------------
struct G4JLSensitiveDetector{UD<:G4JLSDData}
    base::G4JLSensDet
    data::UD
end
struct G4JLProtoSD{UD<:G4JLSDData}
    name::String
    data::UD
    processhits::Union{Function, Nothing}
    initialize::Union{Function, Nothing}
    endofevent::Union{Function, Nothing}
end

"""
    G4JLSensitiveDetector(name::String, data::DATA; <keyword arguments>) where DATA<:G4JLSDData

Initialize a G4JLSensitiveDetector with its name and associated DATA structure.
# Arguments
- `name::String`: Sensitive detector name
- `data::DATA`: Data structure associted to the sensitive detector
- `processhits_method=nothing`: processHit function with signature: `(data::DATA, step::G4Step, ::G4TouchableHistory)::Bool`
- `initialize_method=nothing`: intialize function with signature: `(data::DATA, ::G4HCofThisEvent)::Nothing`
- `endofevent_method=nothing`: endOfEvent function with signature: `(data::DATA, ::G4HCofThisEvent)::Nothing` 
"""
function G4JLSensitiveDetector(name::String, data::T; 
                                processhits_method=nothing,
                                initialize_method=nothing,
                                endofevent_method=nothing) where T<:G4JLSDData
    isnothing(processhits_method) && error("processHits method for ($T,G4Step,G4TouchableHistory) not defined")
    G4JLProtoSD{T}(name, data, processhits_method, initialize_method, endofevent_method)
end

function G4JLSensitiveDetector(sd::G4JLProtoSD)
    (;name, data, processhits, initialize, endofevent) = sd
    tls_data = deepcopy(data)
    cb = make_callback(tls_data, processhits, CxxBool, (CxxPtr{G4Step}, CxxPtr{G4TouchableHistory})) |> closure
    base = G4JLSensDet(name, cb...)
    if !isnothing(initialize)
        cb =  make_callback(tls_data, initialize, Nothing, (CxxPtr{G4HCofThisEvent},)) |> closure
        SetInitialize(base, cb...)
    end
    if !isnothing(endofevent)
        cb =  make_callback(tls_data, endofevent, Nothing, (CxxPtr{G4HCofThisEvent},)) |> closure
        SetEndOfEvent(base, cb...)
    end
    G4JLSensitiveDetector{typeof(data)}(base, tls_data)
end

struct G4JLNoData <: G4JLSimulationData
end

#---Geant4 Application-----------------------------------------------------------------------------
mutable struct G4JLApplication{DET<:G4JLDetector,DAT<:G4JLSimulationData} <: G4JLAbstrcatApp
    const runmanager::Any
    detector::DET
    simdata::Vector{DAT}  # Each worker thread has its own data                            
    generator::G4JLPrimaryGenerator
    field::Union{Nothing, G4Field, G4JLMagneticField} 
    const nthreads::Int32
    const verbose::Int32
    # Types 
    const runmanager_type::Type{<:G4RunManager}
    const builder_type::Type{<:G4VUserDetectorConstruction}
    const physics_type::Type{<:G4VUserPhysicsList}
    const runaction_type::Type{<:G4UserRunAction}
    const eventaction_type::Type{<:G4UserEventAction}
    #stackaction_type::Type{<:G4UserStakingAction}
    const trackaction_type::Type{<:G4UserTrackingAction}
    const stepaction_type::Type{<:G4UserSteppingAction}
    # Methods
    const stepaction_method::Union{Nothing,Function}
    const pretrackaction_method::Union{Nothing,Function}
    const posttrackaction_method::Union{Nothing,Function}
    const beginrunaction_method::Union{Nothing,Function}
    const endrunaction_method::Union{Nothing,Function}
    const begineventaction_method::Union{Nothing,Function}
    const endeventaction_method::Union{Nothing,Function}
    # Sensitive Detectors
    protoSDs::Dict{String,G4JLProtoSD}
    sdetectors::Dict{String,Vector{G4JLSensitiveDetector}} # single and MT
    # Scoring Meshes
    scorers::Vector{G4JLScoringMesh}
    # Instances
    detbuilder::Any
    physics::Any
end
"""
    G4JLApplication(<keyword arguments>)

Initialize a G4JLApplication with its associated tyopes and methods.
# Arguments
- `detector::G4JLDetector`: detector description object
- `simdata=G4JLNoData()`: simulation data object
- `generator=G4JLParticleGun()`: primary particle generator
- `field=nothing`: magnetic field
- `nthreads=0`: number of Geant4 worker threads ( >0 implies MT)
- `verbose=0` : default verbority level (physics, ...)
- `runmanager_type=G4RunManager`: run manager type
- `builder_type=G4JLDetectorConstruction`: detector builder type (the default should be fine most cases)
- `physics_type=FTFP_BERT`: physics list type
- `stepaction_type=G4JLSteppingAction`: stepping action type (the default should be fine most cases)
- `trackaction_type=G4JLTrackingAction`: rtacking action type (the default should be fine most cases)
- `runaction_type=G4JLRunAction`: run action type (the default should be fine most cases)
- `eventaction_type=G4JLEventAction`: event action type (the default should be fine most cases)
- `stepaction_method=nothing`: stepping action method with signature `(::G4Step, ::G4JLApplication)::Nothing`
- `pretrackaction_method=nothing`: pre-tracking action method with signature `(::G4Track, ::G4JLApplication)::Nothing`
- `posttrackaction_method=nothing`: post-tracking action method with signature `(::G4Track, ::G4JLApplication)::Nothing`
- `beginrunaction_method=nothing`: begin run action method with signature `(::G4Run, ::G4JLApplication)::Nothing`
- `endrunaction_method=nothing`: end run action method with signature `(::G4Run, ::G4JLApplication)::Nothing`
- `begineventaction_method=nothing`: begin event action method with signature `(::G4Event, ::G4JLApplication)::Nothing`
- `endeventaction_method=nothing`: end end action method with signature `(::G4Event, ::G4JLApplication)::Nothing`
- `sdetectors::Vector{}=[]`: vector of pairs `lv::String => sd::G4JLSensitiveDetector` to associate logical volumes to sensitive detector
- `scorers::Vector{}=[]`: vector of [`G4JLScoringMesh`](@ref)s
"""
function G4JLApplication(;detector::G4JLDetector,
                simdata=G4JLNoData(),
                generator=G4JLParticleGun(),
                field=nothing,
                nthreads=0,
                verbose=0,
                runmanager_type=G4RunManager,
                builder_type=G4JLDetectorConstruction,
                physics_type=FTFP_BERT,
                stepaction_type=G4JLSteppingAction,
                trackaction_type=G4JLTrackingAction,
                runaction_type=G4JLRunAction,
                eventaction_type=G4JLEventAction,
                stepaction_method=nothing,
                pretrackaction_method=nothing,
                posttrackaction_method=nothing,
                beginrunaction_method=nothing,
                endrunaction_method=nothing,
                begineventaction_method=nothing,
                endeventaction_method=nothing,
                sdetectors=[],
                scorers=[],
                )
    runmanager_type = nthreads > 0 ? G4MTRunManager : runmanager_type # if nthreads > 0 force G4MTRunManager
    G4JLApplication{typeof(detector), typeof(simdata)}( runmanager_type(), detector, [deepcopy(simdata) for i in 1:nthreads+1], generator, 
                                                        field, nthreads, 
                                                        verbose, nthreads > 0 ? G4MTRunManager : G4RunManager, builder_type, physics_type, 
                                                        runaction_type, eventaction_type, trackaction_type, stepaction_type,
                                                        stepaction_method, pretrackaction_method, posttrackaction_method, 
                                                        beginrunaction_method, endrunaction_method, begineventaction_method, endeventaction_method,
                                                        Dict(sdetectors), Dict{String,Vector{G4JLSensitiveDetector}}(), scorers, nothing, nothing)
end

"""
    configure(app::G4JLApplication)
Configure the Geant4 application. It sets the declared user actions, event generator, and physcis list. 
"""
function configure(app::G4JLApplication)
    runmgr = app.runmanager
    #---Set the number of threads and declare G4UserWorkerInitialization---------------------------
    if app.nthreads > 0 
        SetNumberOfThreads(runmgr, app.nthreads)
        SetUserInitialization(runmgr, move!(G4JLWorkerInitialization()))
    end
    #---Prepare SentitiveDetectors-----------------------------------------------------------------
    for (lv,sd) in app.protoSDs
        app.sdetectors[sd.name] = Vector{G4JLSensitiveDetector}(undef, app.nthreads + 1)
    end
    #---Prepare Primary Generators-----------------------------------------------------------------
    app.generator.base = Vector{G4JLGeneratorAction}(undef, app.nthreads + 1)
    #---Prepare Primary Generators-----------------------------------------------------------------
    if app.field isa G4JLMagneticField
        app.field.base = Vector{G4JLMagField}(undef, app.nthreads + 1)
    end
    #---Detector construction----------------------------------------------------------------------
    function sdandf(app::G4JLApplication)::Nothing  # called by the worker thread during init------
        #---Add the Sensitive Detectors now that the geometry is constructed-----------------------
        tid = G4Threading!G4GetThreadId()
        for (lv,protosd) in app.protoSDs
            sd = G4JLSensitiveDetector(protosd)
            app.sdetectors[protosd.name][tid+2] = sd
            if lv[end] == '+'
                lv = lv[1:end-1]
                multi = true
            else
                multi = false
            end
            SetSensitiveDetector(app.detbuilder, lv, CxxPtr(sd.base), multi)
        end
        #---Add Magnetic field if needed-----------------------------------------------------------
        fieldMgr = G4TransportationManager!GetTransportationManager() |> GetFieldManager
        if app.field isa G4Field
            B = Clone(app.field)
            SetDetectorField(fieldMgr, B)
            CreateChordFinder(fieldMgr, CxxPtr{G4MagneticField}(B))
        elseif app.field isa G4JLMagneticField
            sf = make_callback(app.field.data, app.field.getfield, Nothing, (CxxRef{G4ThreeVector}, ConstCxxRef{G4ThreeVector})) |> closure
            B = G4JLMagField(sf...)
            app.field.base[tid+2] = B
            SetDetectorField(fieldMgr, CxxPtr(B))
            CreateChordFinder(fieldMgr, CxxPtr(B))
        end
        nothing
    end
    det    = app.detector
    cb1 = make_callback(det, getConstructor(det), CxxPtr{G4VPhysicalVolume}, ()) |> closure
    cb2 = make_callback(app, sdandf, Nothing, ()) |> closure
    app.detbuilder = app.builder_type(cb1..., cb2...)
    SetUserInitialization(runmgr, CxxPtr(app.detbuilder))
    #---Physics List---------------------------------------------------------------------------
    physics = app.physics_type(app.verbose)
    app.physics = CxxPtr(physics)
    SetUserInitialization(runmgr, move!(physics))
    #---Actions--------------------------------------------------------------------------------
    function build(uai::G4JLActionInitialization, app::G4JLApplication)::Nothing
        if !isnothing(app.stepaction_method)
            cb = make_callback(app, app.stepaction_method, Nothing, (ConstCxxPtr{G4Step},))
            SetUserAction(uai, move!(app.stepaction_type(closure(cb)...)))
        end
        #---Tracking Action---------------------------------------------------------------------------
        if !isnothing(app.pretrackaction_method)
            t1 = make_callback(app, app.pretrackaction_method, Nothing, (ConstCxxPtr{G4Track},)) |> closure
        else
            t1 = null_closure(Nothing, (ConstCxxPtr{G4Track},))
        end
        if !isnothing(app.posttrackaction_method)
            t2 = make_callback(app, app.posttrackaction_method, Nothing, (ConstCxxPtr{G4Track},)) |> closure
        else
            t2 = null_closure(Nothing, (ConstCxxPtr{G4Track},))
        end
        if !isnothing(app.pretrackaction_method) || !isnothing(app.posttrackaction_method)
            SetUserAction(uai, move!(app.trackaction_type(t1..., t2...)))
        end
        #---Run Action---------------------------------------------------------------------------
        if !isnothing(app.beginrunaction_method)
            r1 = make_callback(app, app.beginrunaction_method, Nothing, (ConstCxxPtr{G4Run},)) |> closure
        else
            r1 = null_closure(Nothing, (ConstCxxPtr{G4Run},))
        end
        if !isnothing(app.endrunaction_method)
            r2 = make_callback(app, app.endrunaction_method, Nothing, (ConstCxxPtr{G4Run},)) |> closure
        else
            r2 = null_closure(Nothing, (ConstCxxPtr{G4Run},))
        end
        if !isnothing(app.beginrunaction_method) || !isnothing(app.endrunaction_method)
            SetUserAction(uai, move!(app.runaction_type(r1..., r2...)))
        end
        #---Event Action---------------------------------------------------------------------------
        if !isnothing(app.begineventaction_method)
            e1 = make_callback(app, app.begineventaction_method, Nothing, (ConstCxxPtr{G4Event},)) |> closure
        else
            e1 = null_closure(Nothing, (ConstCxxPtr{G4Event},))
        end
        if !isnothing(app.endeventaction_method)
            e2 = make_callback(app, app.endeventaction_method, Nothing, (ConstCxxPtr{G4Event},)) |> closure
        else
            e2 = null_closure(Nothing, (ConstCxxPtr{G4Event},))
        end
        if !isnothing(app.begineventaction_method) || !isnothing(app.endeventaction_method)
            SetUserAction(uai, move!(app.eventaction_type(e1..., e2...)))
        end
        #---Primary particles generator---------(per thread)--------------------------------------
        gen = app.generator
        tid = G4Threading!G4GetThreadId()
        g1 =  make_callback(gen.data, gen.gen_method, Nothing, (CxxPtr{G4Event},)) |> closure
        gen.base[tid+2] = G4JLGeneratorAction(g1...)
        init_method = gen.init_method
        !isnothing(init_method) && init_method(gen.data, app)
        SetUserAction(uai, CxxPtr(gen.base[tid+2]))
    end
    function master_build(uai::G4JLActionInitialization, app::G4JLApplication)::Nothing
        #---Run Action---------------------------------------------------------------------------
        if !isnothing(app.beginrunaction_method)
            r1 = make_callback(app, app.beginrunaction_method, Nothing, (ConstCxxPtr{G4Run},)) |> closure
        else
            r1 = null_closure(Nothing, (ConstCxxPtr{G4Run},))
        end
        if !isnothing(app.endrunaction_method)
            r2 = make_callback(app, app.endrunaction_method, Nothing, (ConstCxxPtr{G4Run},)) |> closure
        else
            r2 = null_closure(Nothing, (ConstCxxPtr{G4Run},))
        end
        if !isnothing(app.beginrunaction_method) || !isnothing(app.endrunaction_method)
            SetUserAction(uai, move!(app.runaction_type(r1..., r2...)))
        end
    end
    #---User Actions Initialization------------------------------------------------------------
    cb1 = make_callback(app, build, Nothing, (ConstCxxPtr{G4JLActionInitialization},)) |> closure
    cb2 = make_callback(app, master_build, Nothing, (ConstCxxPtr{G4JLActionInitialization},)) |> closure
    ai = G4JLActionInitialization(cb1..., cb2...)
    SetUserInitialization(runmgr, move!(ai))
    #---Setup Scoring--------------------------------------------------------------------------
    if !isempty(app.scorers)
        G4ScoringManager!GetScoringManager()
    end
end
"""
    initialize(app::G4JLApplication)
Initialize the Geant4 application. It initializes the RunManager, which constructs the detector geometry, and sets 
the declared sensitive detectors.
"""
function initialize(app::G4JLApplication)
    Initialize(app.runmanager)
    #---Process scorers------------------------------------------------------------------------
    for sc in app.scorers
        uicmd = toUIstring(sc)
        uimgr = G4UImanager!GetUIpointer()
        for s = eachsplit(uicmd,'\n')
            ApplyCommand(uimgr, String(s)) == 0 || error("Got an error processing UI command '$s'")
        end
        ApplyCommand(uimgr, "/score/close")
        ApplyCommand(uimgr, "/score/list")
    end
end
"""
    reinitialize(app::G4JLApplication, det::G4JLDetector)
Re-initialize the Geant4 application with a new detector defintion.
"""
function reinitialize(app::G4JLApplication, det::G4JLDetector)
    app.detector = det
    runmgr = app.runmanager
    cb1 = make_callback(det, getConstructor(det), CxxPtr{G4VPhysicalVolume}, ()) |> closure
    SetUserInitialization(runmgr, move!(app.builder_type(cb1...)))
    ReinitializeGeometry(runmgr)
    Initialize(runmgr)
end
"""
    beamOn(app::G4JLApplication, nevents::Int)
Start a new run with `nevents` events.
"""
function beamOn(app::G4JLApplication, nevents::Int)
    app.nthreads > 0 && GC.enable(false)  # Disable GC in the run
    BeamOn(app.runmanager, nevents)
    app.nthreads > 0 && GC.enable(true)
    return
end

"""
    getSDdata(app::G4JLApplication, name::String)
Get the data associated to the Sentitive Detector with a given name taking into account the current worker thread ID 
"""
function getSDdata(app, name)
    tid = G4Threading!G4GetThreadId()
    app.sdetectors[name][tid+2].data
end

"""
    getSIMdata(app::G4JLApplication)
Get the Simulation Data taking into account the current worker thread ID 
"""
function getSIMdata(app)
    tid = G4Threading!G4GetThreadId()
    app.simdata[tid+2]
end

"""
    GetWorldVolume()
Get the world volume of the currently instantiated detector geometry.
"""
GetWorldVolume() = GetWorldVolume(GetNavigatorForTracking(G4TransportationManager!GetTransportationManager()))[]
"""
    GetVolume(name::String)
Get the  the G4LogicalVolume with this name.
"""
GetVolume(name::String) = GetVolume(G4LogicalVolumeStore!GetInstance(), name)
