#using Geant4
#using Geant4.SystemOfUnits
#using Geant4.SystemOfUnits: cm3
#using GeometryBasics, Rotations, IGLWrap_jll

mutable struct CrstDetector <: G4JLDetector
    # main input parameters
    const checkOverlaps::Bool
    const crstXY::Float64
    const crstZ::Float64
    const crstName::String
    
    fCrstMaterial::CxxPtr{G4Material}
    #fWrldMaterial::CxxPtr{G4Material}
    
    function CrstDetector(;  crstXY::Float64=3.5mm, 
                             crstZ::Float64=20.0mm,
                             checkOverlaps::Bool=true,
                             crstName="CsI")
        self =  new(checkOverlaps, crstXY, crstZ, crstName)
        nist     = G4NistManager!Instance()
        
        if crstName == "LYSO"
            cm3      = cm * cm * cm
            lyso = G4Material("lyso", density= 7.4*g/cm3, ncomponents=4)
            
            Lu = FindOrBuildElement(nist,"Lu")
            Si = FindOrBuildElement(nist,"Si")
            O  = FindOrBuildElement(nist,"O")
            Y  = FindOrBuildElement(nist,"Y")
            AddElement(lyso, Lu, fractionmass=.71)
            AddElement(lyso, Si, fractionmass=.07)
            AddElement(lyso, O, fractionmass=.18)
            AddElement(lyso, Y, fractionmass=.04)
            self.fCrstMaterial = CxxPtr(lyso)
        elseif crstName == "BGO"
            self.fCrstMaterial  = FindOrBuildMaterial(nist, "G4_BGO")
        else
            self.fCrstMaterial  = FindOrBuildMaterial(nist, "G4_CESIUM_IODIDE")
        end
            
       return self 
    end
end

function crstDetectorConstruction(det::CrstDetector)::CxxPtr{G4VPhysicalVolume}
    (; checkOverlaps, crstXY, crstZ)  = det
    crystBox = G4Box("CBox", crstXY/2,crstXY/2,crstZ/2)

    world_sizeXY   = 2 * crstXY
    world_sizeZ    = 2 * crstZ
    nist           = G4NistManager!Instance()
    worldMaterial  = FindOrBuildMaterial(nist, "G4_AIR")
    
    solidworld = G4Box("World",  0.5*world_sizeXY, 0.5*world_sizeXY, 0.5*world_sizeZ)   
    logicworld = G4LogicalVolume(move!(solidworld), worldMaterial, "World")
    physWorld  = G4PVPlacement(nothing,          # no rotation
                              G4ThreeVector(),  # at (0,0,0)
                              logicworld,       # its logical volume
                              "World",          # its name
                              nothing,          # its mother volume
                              false,            # no boolean operation
                              0,                # copy number
                              checkOverlaps)                # overlaps checking 
    # Crystal
    solidcrst = G4Box("CRYSTAL", 0.5 * crstXY, 0.5 * crstXY, 0.5 * crstZ)
    logiccrst = G4LogicalVolume(move!(solidcrst),  det.fCrstMaterial, "CRYSTAL")
    G4PVPlacement(nothing,           # no rotation
                  G4ThreeVector(),   # at (0,0,0)
                  logiccrst,          # its logical volume
                  "CRYSTAL",            # its name
                  logicworld,        # its mother  volume
                  false,             # no boolean operation
                  0,                 # copy number
                  checkOverlaps)     # overlaps checking
    
    SetVisAttributes(logicworld, G4VisAttributes!GetInvisible())
    SetVisAttributes(logiccrst, G4VisAttributes(G4Colour(1.0, 1.0, 0.0)))
    
    return physWorld              # return a pointer to the G4PhysicalVolume
end

Geant4.getConstructor(::CrstDetector)::Function = crstDetectorConstruction