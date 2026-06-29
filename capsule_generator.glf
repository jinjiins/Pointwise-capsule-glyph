###############################################################################
# Capsule-type Grid Generator v1
###############################################################################

package require PWI_Glyph 3.18.3

pw::Application reset
pw::Application clearModified

set pi 3.141592653589793
set rad [expr {$pi / 180.0}]

###############################################################################
## User Input
###############################################################################

# 형상 입력
set Rb 3.0
set RnRb_ratio 1.5
set Rn [expr {$Rb / $RnRb_ratio}]
set Rs 0.2
set thetac 70.0

# 도메인 옵션
# IsAxi = 0: full 360-degree domain
# IsAxi = 1: half 180-degree domain, theta = -90 deg ~ +90 deg.
#            이 경우 두 방위각 경계면은 y=0 평면에 놓이고 extrusion BC는 Constant Y로 설정된다.
set IsAxi 0

# IsExtrude = 0: database + surface mesh만 생성
# IsExtrude = 1: surface mesh에서 실제 표면 normal 방향으로 structured block extrusion 수행
set IsExtrude 1

# 360도 기준 둘레 방향 총 격자 셀 수.
# Half domain(IsAxi=1)에서는 실제 활성 방위각 셀 수가 Nconnector/2가 된다.
# Butterfly 연결을 위해 항상 8의 배수여야 한다.
set Nconnector 64

# Butterfly 영역이 전체 nose arc에서 차지하는 비율 (0 < 값 < 1)
# 0.45이면 정체점에서 nose-frustum 접점까지 arc의 45% 지점에 전이 링 생성.
set butterflyFraction 0.6

# 후방 정렬 격자의 축방향 셀 수.
# 0이면 Nconnector를 기준으로 종횡비가 대략 1이 되도록 자동 계산.
set NnoseAlignedCells 10
set NfrustumCells 71
set NedgeCells 9

# Butterfly 내부의 물리적 interior edge에 Floating BC를 적용한 뒤
# 수행할 elliptic solver iteration 수. 0이면 Butterfly smoothing을 생략한다.
set butterflyFloatingIterations 15

# Butterfly 이후의 aligned strip에 적용할 elliptic solver iteration 수.
# 0이면 후방 smoothing을 수행하지 않는다.
set ellipticIterations 40

# Normal extrusion 입력.
# GrowthRate(i), GrowthIteration(i)를 phase별로 지정한다.
# GrowthPhaseCount = auto: GrowthRate/GrowthIteration 배열에서 연속 정의된 phase를 자동 인식한다.

set FirstLayerHeight 5.0e-6
set GrowthPhaseCount auto
set GrowthRate(1) 1.2
set GrowthIteration(1) 30
set GrowthRate(2) 1.0
set GrowthIteration(2) 80
set GrowthRate(3) 1.2
set GrowthIteration(3) 30

# AutoOrientWallNormal=1일 때:
#   ExtrudeFlip = 0: outward wall-normal marching
#   ExtrudeFlip = 1: 전체 block을 반대로 뒤집음, 즉 inward/debug marching
#
# AutoOrientWallNormal=0일 때:
#   ExtrudeFlip은 모든 block에 동일하게 적용되는 Pointwise DirectionFlipped 값이다.
set AutoOrientWallNormal 1
set ExtrudeFlip 0

# BlockStructured normal extrusion에서는 NormalKinseyBarthSmoothing이
# Default 또는 {i j} 형태를 요구한다. 스칼라를 넣으면 아래 utility에서 {값 값}으로 변환한다.
set NormalKinseyBarthSmoothing {3 3}
set NormalVolumeSmoothing 0.3

# Half-domain symmetry boundary constraint. GUI label: Constant Y. Glyph enum is usually ConstantY.
set HalfDomainBoundaryConstraint ConstantY

# Shoulder 끝단, 즉 P4 aft ring은 x=P4x 평면에 놓여야 하므로 normal extrusion 중 해당 boundary edge를 Constant X로 묶는다.

# IsShoulderEndConstraint = 1: aligned-strip의 aft/shoulder-end edge에 Constant X 적용
# IsShoulderEndConstraint = 0: 해당 constraint 생략
set IsShoulderEndConstraint 1
set ShoulderEndBoundaryConstraint ConstantX

###############################################################################

if {$Rb <= 0.0} {
    error "Rb must be greater than zero."
}
if {$RnRb_ratio <= 0.0} {
    error "RnRb_ratio must be greater than zero."
}
if {$Rn <= 0.0} {
    error "Rn must be greater than zero."
}
if {$Rs <= 0.0 || $Rs >= $Rb} {
    error "Rs must satisfy 0 < Rs < Rb."
}
if {$thetac <= 0.0 || $thetac >= 90.0} {
    error "thetac must satisfy 0 < thetac < 90 degrees."
}
if {![string is integer -strict $IsAxi] || ($IsAxi != 0 && $IsAxi != 1)} {
    error "IsAxi must be either 0 or 1."
}
if {![string is integer -strict $IsExtrude] || ($IsExtrude != 0 && $IsExtrude != 1)} {
    error "IsExtrude must be either 0 or 1."
}
if {![string is integer -strict $AutoOrientWallNormal] || ($AutoOrientWallNormal != 0 && $AutoOrientWallNormal != 1)} {
    error "AutoOrientWallNormal must be either 0 or 1."
}
if {![string is integer -strict $ExtrudeFlip] || ($ExtrudeFlip != 0 && $ExtrudeFlip != 1)} {
    error "ExtrudeFlip must be either 0 or 1."
}
if {![string is integer -strict $IsShoulderEndConstraint] || ($IsShoulderEndConstraint != 0 && $IsShoulderEndConstraint != 1)} {
    error "IsShoulderEndConstraint must be either 0 or 1."
}
if {![string is integer -strict $Nconnector] || $Nconnector < 8 || ($Nconnector % 8) != 0} {
    error "Nconnector must be an integer multiple of 8 and at least 8."
}
if {$butterflyFraction <= 0.0 || $butterflyFraction >= 1.0} {
    error "butterflyFraction must satisfy 0 < butterflyFraction < 1."
}
foreach value [list $NnoseAlignedCells $NfrustumCells $NedgeCells] {
    if {![string is integer -strict $value] || $value < 0} {
        error "Axial cell counts must be non-negative integers."
    }
}
foreach value [list $butterflyFloatingIterations $ellipticIterations] {
    if {![string is integer -strict $value] || $value < 0} {
        error "Elliptic solver iteration counts must be non-negative integers."
    }
}
if {$IsExtrude} {
    if {$FirstLayerHeight <= 0.0} {
        error "FirstLayerHeight must be greater than zero when IsExtrude=1."
    }

    # Detect the highest phase index for which both GrowthRate(i) and
    # GrowthIteration(i) are defined. This prevents a newly-added phase from
    # being silently ignored when GrowthPhaseCount was not updated.
    set definedGrowthPhases [list]
    foreach key [array names GrowthRate] {
        if {[string is integer -strict $key] && $key >= 1 && [info exists GrowthIteration($key)]} {
            lappend definedGrowthPhases $key
        }
    }
    set definedGrowthPhases [lsort -integer -unique $definedGrowthPhases]
    if {[llength $definedGrowthPhases] == 0} {
        error "At least one GrowthRate(i)/GrowthIteration(i) phase must be defined when IsExtrude=1."
    }
    set maxDefinedGrowthPhase [lindex $definedGrowthPhases end]

    if {[string equal -nocase $GrowthPhaseCount "auto"]} {
        set GrowthPhaseCount $maxDefinedGrowthPhase
    } elseif {![string is integer -strict $GrowthPhaseCount]} {
        error "GrowthPhaseCount must be a positive integer, 0, or auto when IsExtrude=1."
    } elseif {$GrowthPhaseCount == 0} {
        set GrowthPhaseCount $maxDefinedGrowthPhase
    } elseif {$GrowthPhaseCount < 1} {
        error "GrowthPhaseCount must be a positive integer, 0, or auto when IsExtrude=1."
    } elseif {$GrowthPhaseCount < $maxDefinedGrowthPhase} {
        puts [format "Warning: GrowthPhaseCount=%d but GrowthRate/GrowthIteration are defined through phase %d. Expanding GrowthPhaseCount to %d." \
            $GrowthPhaseCount $maxDefinedGrowthPhase $maxDefinedGrowthPhase]
        set GrowthPhaseCount $maxDefinedGrowthPhase
    }

    set totalRequestedExtrusionLayers 0
    for {set phase 1} {$phase <= $GrowthPhaseCount} {incr phase} {
        if {![info exists GrowthRate($phase)]} {
            error "GrowthRate($phase) is not defined. Growth phases must be contiguous from 1 to GrowthPhaseCount."
        }
        if {![info exists GrowthIteration($phase)]} {
            error "GrowthIteration($phase) is not defined. Growth phases must be contiguous from 1 to GrowthPhaseCount."
        }
        if {$GrowthRate($phase) <= 0.0} {
            error "GrowthRate($phase) must be greater than zero."
        }
        if {![string is integer -strict $GrowthIteration($phase)] || $GrowthIteration($phase) < 0} {
            error "GrowthIteration($phase) must be a non-negative integer."
        }
        incr totalRequestedExtrusionLayers $GrowthIteration($phase)
    }
    if {$totalRequestedExtrusionLayers <= 0} {
        error "At least one GrowthIteration phase must have a positive layer count when IsExtrude=1."
    }
}

if {$IsAxi} {
    set isClosedAzimuth 0
    set activeAngleDegrees 180.0
    set activeAngle [expr {$pi}]
    set thetaStart [expr {-$pi / 2.0}]
    set topologySectorCount 4
    set topologyQuadrantCount 2
    set activeCircumferentialCells [expr {$Nconnector / 2}]
} else {
    set isClosedAzimuth 1
    set activeAngleDegrees 360.0
    set activeAngle [expr {2.0 * $pi}]
    set thetaStart 0.0
    set topologySectorCount 8
    set topologyQuadrantCount 4
    set activeCircumferentialCells $Nconnector
}

if {($activeCircumferentialCells % $topologySectorCount) != 0} {
    error "The active circumferential cell count must be divisible by the topology sector count."
}

set topologyBoundaryCount [expr {$isClosedAzimuth ? $topologySectorCount : ($topologySectorCount + 1)}]
set topologyCornerCount [expr {$isClosedAzimuth ? $topologyQuadrantCount : ($topologyQuadrantCount + 1)}]
set cellsPerSector [expr {$activeCircumferentialCells / $topologySectorCount}]
set circumferentialSectorDimension [expr {$cellsPerSector + 1}]
set butterflyConnectorDimension $circumferentialSectorDimension

# Cylindrical point about the X axis: x, radius, azimuth angle [rad]
proc pointOnRing {x radius theta} {
    return [list \
        $x \
        [expr {$radius * cos($theta)}] \
        [expr {$radius * sin($theta)}]]
}

# Normal vector to the meridional profile plane. The sign is selected so that
# theta=0 reproduces the original XY-profile circle axis {0 0 -1}.
proc meridionalPlaneAxis {theta} {
    return [list 0.0 [expr {sin($theta)}] [expr {-cos($theta)}]]
}

# Project a point radially onto a sphere.
proc projectPointToSphere {point center radius} {
    set vec [pwu::Vector3 subtract $point $center]
    set length [pwu::Vector3 length $vec]
    if {$length <= 1.0e-14} {
        error "Cannot project the sphere center onto the sphere."
    }
    set unit [pwu::Vector3 scale $vec [expr {1.0 / $length}]]
    return [pwu::Vector3 add $center [pwu::Vector3 scale $unit $radius]]
}

# Point on the spherical nose. alpha=0 at the stagnation point.
proc nosePoint {center radius alpha theta} {
    set x [expr {[lindex $center 0] - $radius * cos($alpha)}]
    set rr [expr {$radius * sin($alpha)}]
    return [pointOnRing $x $rr $theta]
}

# Create a two-point straight connector.
proc createLineConnector {point1 point2 dimension name} {
    set segment [pw::SegmentSpline create]
    $segment addPoint $point1
    $segment addPoint $point2

    set connector [pw::Connector create]
    $connector addSegment $segment
    $connector setDimension $dimension
    if {$name ne ""} {
        $connector setName $name
    }
    return $connector
}

# Create an exact circular-arc connector from two points and a center.
proc createCircleArcConnector {point1 point2 center dimension name} {
    set vec1 [pwu::Vector3 subtract $point1 $center]
    set vec2 [pwu::Vector3 subtract $point2 $center]
    set axis [pwu::Vector3 cross $vec1 $vec2]
    set axisLength [pwu::Vector3 length $axis]

    if {$axisLength <= 1.0e-14} {
        return [createLineConnector $point1 $point2 $dimension $name]
    }
    set axis [pwu::Vector3 scale $axis [expr {1.0 / $axisLength}]]

    set segment [pw::SegmentCircle create]
    $segment addPoint $point1
    $segment addPoint $point2
    $segment setCenterPoint $center $axis

    set connector [pw::Connector create]
    $connector addSegment $segment
    $connector setDimension $dimension
    if {$name ne ""} {
        $connector setName $name
    }
    return $connector
}

# Create a circumferential circular-arc connector about the X axis.
proc createRingArcConnector {point1 point2 center dimension name} {
    set segment [pw::SegmentCircle create]
    $segment addPoint $point1
    $segment addPoint $point2
    $segment setCenterPoint $center {1 0 0}

    set connector [pw::Connector create]
    $connector addSegment $segment
    $connector setDimension $dimension
    if {$name ne ""} {
        $connector setName $name
    }
    return $connector
}

# Build exactly one logical structured edge from the supplied connector chain.
proc createStructuredEdge {connectorList} {
    if {[llength $connectorList] == 0} {
        error "An empty connector list cannot define an edge."
    }

    set edge [pw::Edge create]
    foreach connector $connectorList {
        $edge addConnector $connector
    }
    return $edge
}

# Create a four-edge structured domain. Each logical side may contain one or
# more geometric connectors.
proc createStructuredDomain {side1 side2 side3 side4 name} {
    set domain [pw::DomainStructured create]
    foreach side [list $side1 $side2 $side3 $side4] {
        $domain addEdge [createStructuredEdge $side]
    }

    if {![$domain isValid]} {
        pw::Entity delete $domain
        error "Invalid structured-domain topology while creating $name."
    }

    if {$name ne ""} {
        $domain setName $name
    }
    return $domain
}

# Automatic axial cell count based on local circumferential spacing.
proc automaticAxialCells {length averageRadius activeCircumferentialCells activeAngle} {
    if {$length <= 0.0} {
        return 1
    }
    if {$averageRadius <= 1.0e-12} {
        return 2
    }

    set targetSpacing [expr {$activeAngle * $averageRadius / double($activeCircumferentialCells)}]
    set count [expr {int(ceil($length / $targetSpacing))}]
    if {$count < 2} {
        set count 2
    }
    return $count
}

proc nextBoundaryIndex {sector boundaryCount isClosedAzimuth} {
    set next [expr {$sector + 1}]
    if {$isClosedAzimuth && $next >= $boundaryCount} {
        set next 0
    }
    return $next
}

proc nextCornerIndex {corner cornerCount isClosedAzimuth} {
    set next [expr {$corner + 1}]
    if {$isClosedAzimuth && $next >= $cornerCount} {
        set next 0
    }
    return $next
}

proc createBlockFromStructuredDomain {domain name} {
    set face [lindex [pw::FaceStructured createFromDomains [list $domain]] 0]
    set block [pw::BlockStructured create]
    $block addFace $face
    if {$name ne ""} {
        catch {$block setName $name}
    }
    return $block
}

proc edgeIndexToStructuredSideCandidates {edgeIndex} {
    switch -- $edgeIndex {
        1 {return {JMinimum IMinimum}}
        2 {return {IMaximum JMinimum}}
        3 {return {JMaximum IMaximum}}
        4 {return {IMinimum JMaximum}}
        default {return {}}
    }
}

# Convert Pointwise BlockStructured normal-extrusion ij_vector-style inputs.
# Accepted user inputs:
#   Default
#   3       -> {3 3}
#   {3 3}   -> {3 3}
proc normalizeIJVectorOrDefault {value attributeName} {
    if {[string equal -nocase $value "Default"]} {
        return Default
    }

    set componentCount [llength $value]
    if {$componentCount == 1} {
        if {![string is double -strict $value]} {
            error "$attributeName must be Default, a scalar, or a two-component ij_vector."
        }
        return [list $value $value]
    }

    if {$componentCount == 2} {
        set first [lindex $value 0]
        set second [lindex $value 1]
        if {![string is double -strict $first] || ![string is double -strict $second]} {
            error "$attributeName ij_vector components must be numeric."
        }
        return [list $first $second]
    }

    error "$attributeName must be Default, a scalar, or a two-component ij_vector."
}

proc safeSetExtrusionSolverAttribute {entity attribute value {required 0}} {
    if {[catch {$entity setExtrusionSolverAttribute $attribute $value} message]} {
        if {$required} {
            error [format "Failed to set required extrusion attribute %s=%s: %s" \
                $attribute $value $message]
        }

        if {[catch {$entity getName} entityName]} {
            set entityName "<unnamed>"
        }
        puts [format "Warning: skipped optional extrusion attribute %s=%s on %s: %s" \
            $attribute $value $entityName $message]
        return 0
    }
    return 1
}

# Boundary-condition names are displayed in the GUI with spaces, e.g. "Constant X",
# while Glyph builds commonly accept compact enum-style names, e.g. ConstantX.
# Try both so the script is less sensitive to version-specific parsing.
proc normalExtrusionBoundaryConditionCandidates {condition} {
    set normalized [string map {" " "" "_" "" "-" ""} $condition]
    set lower [string tolower $normalized]

    switch -- $lower {
        constantx {return [list ConstantX {Constant X}]}
        constanty {return [list ConstantY {Constant Y}]}
        constantz {return [list ConstantZ {Constant Z}]}
        symmetryx {return [list SymmetryX {Symmetry X}]}
        symmetryy {return [list SymmetryY {Symmetry Y}]}
        symmetryz {return [list SymmetryZ {Symmetry Z}]}
        floatingx {return [list FloatingX {Floating X}]}
        floatingy {return [list FloatingY {Floating Y}]}
        floatingz {return [list FloatingZ {Floating Z}]}
        default {return [list $condition]}
    }
}

# Apply a normal-extrusion boundary condition to a specific base-domain edge.
# Different Pointwise versions accept different selectors; this routine tries the
# exact edge object first, then the numeric edge index, structured side names,
# and finally optional selector hints such as the connector on that boundary.
proc setBlockExtrusionBoundaryConditionOnDomainEdge {block domain edgeIndex condition {required 0} {selectorHints {}}} {
    set primarySelectors [list]
    if {![catch {$domain getEdge $edgeIndex} edgeObject]} {
        lappend primarySelectors $edgeObject
    }
    lappend primarySelectors $edgeIndex
    foreach candidate [edgeIndexToStructuredSideCandidates $edgeIndex] {
        lappend primarySelectors $candidate
    }

    # First try selectors that should represent the whole domain side.
    # This is preferable for logical edges made from multiple connectors.
    foreach conditionCandidate [normalExtrusionBoundaryConditionCandidates $condition] {
        foreach selector $primarySelectors {
            if {![catch {$block setExtrusionBoundaryCondition $selector $conditionCandidate}]} {
                catch {$block setExtrusionBoundaryConditionStepSuppression $selector 0.0}
                return 1
            }
        }
    }

    # If the Pointwise version wants actual boundary connectors, apply the same
    # condition to every connector hint supplied for this logical edge.
    if {[llength $selectorHints] > 0} {
        foreach conditionCandidate [normalExtrusionBoundaryConditionCandidates $condition] {
            set allHintsApplied 1
            foreach selector $selectorHints {
                if {[catch {$block setExtrusionBoundaryCondition $selector $conditionCandidate}]} {
                    set allHintsApplied 0
                    break
                }
                catch {$block setExtrusionBoundaryConditionStepSuppression $selector 0.0}
            }
            if {$allHintsApplied} {
                return 1
            }
        }
    }

    set message [format "Unable to apply extrusion BC %s to block %s, domain %s edge %d." \
        $condition [$block getName] [$domain getName] $edgeIndex]
    if {$required} {
        error $message
    }
    puts [format "Warning: %s" $message]
    return 0
}

# P1: Stagnation point / nose tip
set P1 [list 0.0 0.0 0.0]

# P2: Nose-frustum 접점, expressed as x and radial distance from X axis
set P2x [expr {$Rn * (1.0 - sin($thetac * $rad))}]
set P2r [expr {$Rn * cos($thetac * $rad)}]
set P2 [list $P2x $P2r 0.0]
set centerNose [list $Rn 0.0 0.0]

# P3: Frustum-shoulder 접점
set term1 [expr {$Rn * (1.0 - sin($thetac * $rad))}]
set term2_num [expr {$Rb - $Rn * cos($thetac * $rad) - $Rs * (1.0 - cos($thetac * $rad))}]
set term2_den [expr {tan($thetac * $rad)}]
set P3x [expr {$term1 + $term2_num / $term2_den}]
set P3r [expr {$Rb - $Rs * (1.0 - cos($thetac * $rad))}]
set P3 [list $P3x $P3r 0.0]

# P4: Shoulder 끝점
set P4x [expr {$P3x + $Rs * sin($thetac * $rad)}]
set P4r $Rb
set P4 [list $P4x $P4r 0.0]
set centerShoulder [list $P4x [expr {$Rb - $Rs}] 0.0]

# Butterfly transition ring on the spherical nose
set noseArcAngle [expr {$pi / 2.0 - $thetac * $rad}]
set butterflyAngle [expr {$butterflyFraction * $noseArcAngle}]
set PBx [expr {$Rn * (1.0 - cos($butterflyAngle))}]
set PBr [expr {$Rn * sin($butterflyAngle)}]

set profileCreator [pw::Application begin Create]

set profileCurve [pw::Curve create]
$profileCurve setName "spherecone-profile"

# For half-domain extrusion with Constant Y symmetry planes, the profile starts at
# theta=-90 deg and is revolved by +180 deg to theta=+90 deg.
set profileThetaStart $thetaStart
set profilePlaneAxis [meridionalPlaneAxis $profileThetaStart]

set P2profile [pointOnRing $P2x $P2r $profileThetaStart]
set P3profile [pointOnRing $P3x $P3r $profileThetaStart]
set P4profile [pointOnRing $P4x $P4r $profileThetaStart]
set centerShoulderProfile [pointOnRing $P4x [expr {$Rb - $Rs}] $profileThetaStart]

# Nose circle
set segNose [pw::SegmentCircle create]
$segNose addPoint $P1
$segNose addPoint $P2profile
$segNose setCenterPoint $centerNose $profilePlaneAxis
$profileCurve addSegment $segNose

# Frustum line
set segFrustum [pw::SegmentSpline create]
$segFrustum addPoint $P2profile
$segFrustum addPoint $P3profile
$profileCurve addSegment $segFrustum

# Shoulder circle
set segShoulder [pw::SegmentCircle create]
$segShoulder addPoint $P3profile
$segShoulder addPoint $P4profile
$segShoulder setCenterPoint $centerShoulderProfile $profilePlaneAxis
$profileCurve addSegment $segShoulder

set sphereConeSurface [pw::Surface create]
$sphereConeSurface revolve -angle $activeAngleDegrees $profileCurve $P1 {1 0 0}
$sphereConeSurface setName "spherecone-surface"

$profileCreator end

# Axisymmetric section lengths used for optional automatic dimensions.
set noseAlignedLength [expr {$Rn * ($noseArcAngle - $butterflyAngle)}]
set frustumLength [expr {sqrt(($P3x - $P2x) * ($P3x - $P2x) + ($P3r - $P2r) * ($P3r - $P2r))}]
set edgeLength [expr {$Rs * $thetac * $rad}]

if {$NnoseAlignedCells == 0} {
    set NnoseAlignedCells [automaticAxialCells \
        $noseAlignedLength [expr {0.5 * ($PBr + $P2r)}] \
        $activeCircumferentialCells $activeAngle]
}
if {$NfrustumCells == 0} {
    set NfrustumCells [automaticAxialCells \
        $frustumLength [expr {0.5 * ($P2r + $P3r)}] \
        $activeCircumferentialCells $activeAngle]
}
if {$NedgeCells == 0} {
    set NedgeCells [automaticAxialCells \
        $edgeLength [expr {0.5 * ($P3r + $P4r)}] \
        $activeCircumferentialCells $activeAngle]
}

set noseAlignedDimension [expr {$NnoseAlignedCells + 1}]
set frustumDimension [expr {$NfrustumCells + 1}]
set edgeDimension [expr {$NedgeCells + 1}]
set totalAxialCells [expr {$NnoseAlignedCells + $NfrustumCells + $NedgeCells}]

set gridCreator [pw::Application begin Create]

# Topological azimuth boundaries. Full domain is closed; half domain has two open
# symmetry-plane boundaries at theta=-90 deg and theta=+90 deg.
for {set boundary 0} {$boundary < $topologyBoundaryCount} {incr boundary} {
    set theta [expr {$thetaStart + $activeAngle * double($boundary) / double($topologySectorCount)}]

    set transitionPoint($boundary) [pointOnRing $PBx $PBr $theta]
    set p2Point($boundary) [pointOnRing $P2x $P2r $theta]
    set p3Point($boundary) [pointOnRing $P3x $P3r $theta]
    set aftPoint($boundary) [pointOnRing $P4x $P4r $theta]
}

# Transition and aft rings: one connector per topological sector.
for {set sector 0} {$sector < $topologySectorCount} {incr sector} {
    set next [nextBoundaryIndex $sector $topologyBoundaryCount $isClosedAzimuth]

    set transitionRingCon($sector) [createRingArcConnector \
        $transitionPoint($sector) \
        $transitionPoint($next) \
        [list $PBx 0.0 0.0] \
        $circumferentialSectorDimension \
        [format "transition-ring-%d" $sector]]

    set aftRingCon($sector) [createRingArcConnector \
        $aftPoint($sector) \
        $aftPoint($next) \
        [list $P4x 0.0 0.0] \
        $circumferentialSectorDimension \
        [format "aft-ring-%d" $sector]]
}

# Each azimuthal boundary has three geometric connectors, but the three are
# later added to one logical structured edge.
for {set boundary 0} {$boundary < $topologyBoundaryCount} {incr boundary} {
    set theta [expr {$thetaStart + $activeAngle * double($boundary) / double($topologySectorCount)}]

    set meridianNoseCon($boundary) [createCircleArcConnector \
        $transitionPoint($boundary) \
        $p2Point($boundary) \
        $centerNose \
        $noseAlignedDimension \
        [format "extrude-nose-%d" $boundary]]

    set meridianFrustumCon($boundary) [createLineConnector \
        $p2Point($boundary) \
        $p3Point($boundary) \
        $frustumDimension \
        [format "extrude-frustum-%d" $boundary]]

    set shoulderCenterAtTheta [pointOnRing \
        $P4x [expr {$Rb - $Rs}] $theta]
    set meridianEdgeCon($boundary) [createCircleArcConnector \
        $p3Point($boundary) \
        $aftPoint($boundary) \
        $shoulderCenterAtTheta \
        $edgeDimension \
        [format "extrude-edge-%d" $boundary]]

    set meridianConnectorChain($boundary) [list \
        $meridianNoseCon($boundary) \
        $meridianFrustumCon($boundary) \
        $meridianEdgeCon($boundary)]
}


# Split points exist at 90-degree quadrant boundaries.
for {set corner 0} {$corner < $topologyCornerCount} {incr corner} {
    set cornerBoundary [expr {2 * $corner}]
    set cornerTheta [expr {$thetaStart + $activeAngle * double($cornerBoundary) / double($topologySectorCount)}]

    set splitPoint($corner) \
        [nosePoint $centerNose $Rn [expr {0.5 * $butterflyAngle}] $cornerTheta]
    set outerCornerPoint($corner) $transitionPoint($cornerBoundary)
}

# One TriQuad center and one mid-point per 90-degree quadrant.
for {set quadrant 0} {$quadrant < $topologyQuadrantCount} {incr quadrant} {
    set nextQuadrant [nextCornerIndex $quadrant $topologyCornerCount $isClosedAzimuth]
    set midBoundary [expr {2 * $quadrant + 1}]

    set outerMidPoint($quadrant) $transitionPoint($midBoundary)

    set sum01 [pwu::Vector3 add $splitPoint($quadrant) $outerMidPoint($quadrant)]
    set sum012 [pwu::Vector3 add $sum01 $splitPoint($nextQuadrant)]
    set rawCenter [pwu::Vector3 scale $sum012 [expr {1.0 / 3.0}]]
    set triCenter($quadrant) \
        [projectPointToSphere $rawCenter $centerNose $Rn]
}

# Shared radial connectors at quadrant boundaries.
for {set corner 0} {$corner < $topologyCornerCount} {incr corner} {
    set radialTipCon($corner) [createCircleArcConnector \
        $P1 \
        $splitPoint($corner) \
        $centerNose \
        $butterflyConnectorDimension \
        [format "butterfly-tip-radial-%d" $corner]]

    set radialOuterCon($corner) [createCircleArcConnector \
        $splitPoint($corner) \
        $outerCornerPoint($corner) \
        $centerNose \
        $butterflyConnectorDimension \
        [format "butterfly-outer-radial-%d" $corner]]
}

# Three interior connectors per triangular quadrant.
for {set quadrant 0} {$quadrant < $topologyQuadrantCount} {incr quadrant} {
    set nextQuadrant [nextCornerIndex $quadrant $topologyCornerCount $isClosedAzimuth]

    set innerConA($quadrant) [createCircleArcConnector \
        $splitPoint($quadrant) \
        $triCenter($quadrant) \
        $centerNose \
        $butterflyConnectorDimension \
        [format "butterfly-A-center-%d" $quadrant]]

    set innerConM($quadrant) [createCircleArcConnector \
        $outerMidPoint($quadrant) \
        $triCenter($quadrant) \
        $centerNose \
        $butterflyConnectorDimension \
        [format "butterfly-M-center-%d" $quadrant]]

    set innerConB($quadrant) [createCircleArcConnector \
        $splitPoint($nextQuadrant) \
        $triCenter($quadrant) \
        $centerNose \
        $butterflyConnectorDimension \
        [format "butterfly-B-center-%d" $quadrant]]
}

set allDomains [list]
set butterflyDomains [list]
set alignedDomains [list]
set butterflyFloatingDomainEdges [list]
set halfSymmetryDomainEdges [list]
set shoulderEndDomainEdges [list]

# Raw domain orientation audit for normal extrusion:
#   butterfly domains are ordered opposite to the downstream aligned strips.
#   1 means DirectionFlipped=true is needed for outward marching from that source face.
#   0 means raw DirectionFlipped=false already marches outward.
array set domainOutwardFlipNeeded {}

for {set quadrant 0} {$quadrant < $topologyQuadrantCount} {incr quadrant} {
    set nextQuadrant [nextCornerIndex $quadrant $topologyCornerCount $isClosedAzimuth]
    set firstSector [expr {2 * $quadrant}]
    set secondSector [expr {2 * $quadrant + 1}]

    # Quad adjacent to the first outer corner O_i.
    set domainA [createStructuredDomain \
        [list $radialOuterCon($quadrant)] \
        [list $transitionRingCon($firstSector)] \
        [list $innerConM($quadrant)] \
        [list $innerConA($quadrant)] \
        [format "butterfly-q%d-cornerA" $quadrant]]
    lappend allDomains $domainA
    lappend butterflyDomains $domainA
    set domainOutwardFlipNeeded($domainA) 1
    lappend butterflyFloatingDomainEdges [list $domainA 3] [list $domainA 4]

    if {$IsAxi && $quadrant == 0} {
        lappend halfSymmetryDomainEdges [list $domainA 1 [list $radialOuterCon($quadrant)]]
    }

    # Quad adjacent to the second outer corner O_(i+1).
    set domainB [createStructuredDomain \
        [list $innerConB($quadrant)] \
        [list $innerConM($quadrant)] \
        [list $transitionRingCon($secondSector)] \
        [list $radialOuterCon($nextQuadrant)] \
        [format "butterfly-q%d-cornerB" $quadrant]]
    lappend allDomains $domainB
    lappend butterflyDomains $domainB
    set domainOutwardFlipNeeded($domainB) 1
    lappend butterflyFloatingDomainEdges [list $domainB 1] [list $domainB 2]

    if {$IsAxi && $quadrant == ($topologyQuadrantCount - 1)} {
        lappend halfSymmetryDomainEdges [list $domainB 4 [list $radialOuterCon($nextQuadrant)]]
    }

    # Quad adjacent to the stagnation point.
    set domainTip [createStructuredDomain \
        [list $radialTipCon($quadrant)] \
        [list $innerConA($quadrant)] \
        [list $innerConB($quadrant)] \
        [list $radialTipCon($nextQuadrant)] \
        [format "butterfly-q%d-tip" $quadrant]]
    lappend allDomains $domainTip
    lappend butterflyDomains $domainTip
    set domainOutwardFlipNeeded($domainTip) 1
    lappend butterflyFloatingDomainEdges [list $domainTip 2] [list $domainTip 3]

    if {$IsAxi && $quadrant == 0} {
        lappend halfSymmetryDomainEdges [list $domainTip 1 [list $radialTipCon($quadrant)]]
    }
    if {$IsAxi && $quadrant == ($topologyQuadrantCount - 1)} {
        lappend halfSymmetryDomainEdges [list $domainTip 4 [list $radialTipCon($nextQuadrant)]]
    }
}

# One domain spans transition ring -> nose/frustum -> shoulder edge.
# The two meridional sides are each one logical edge made from three connectors.
for {set sector 0} {$sector < $topologySectorCount} {incr sector} {
    set next [nextBoundaryIndex $sector $topologyBoundaryCount $isClosedAzimuth]

    set domain [createStructuredDomain \
        [list $transitionRingCon($sector)] \
        $meridianConnectorChain($next) \
        [list $aftRingCon($sector)] \
        $meridianConnectorChain($sector) \
        [format "aligned-strip-%d" $sector]]

    lappend allDomains $domain
    lappend alignedDomains $domain
    set domainOutwardFlipNeeded($domain) 0

    # Edge 3 of the aligned strip is the aft shoulder-end ring at x=P4x.
    # During outward normal extrusion, constrain it to Constant X so the
    # downstream end remains a planar x-constant boundary.
    lappend shoulderEndDomainEdges [list $domain 3 [list $aftRingCon($sector)]]

    if {$IsAxi && $sector == 0} {
        lappend halfSymmetryDomainEdges [list $domain 4 $meridianConnectorChain($sector)]
    }
    if {$IsAxi && $sector == ($topologySectorCount - 1)} {
        lappend halfSymmetryDomainEdges [list $domain 2 $meridianConnectorChain($next)]
    }
}

$gridCreator end

foreach domain $allDomains {
    $domain project -type ClosestPoint [list $sphereConeSurface]
}


if {$butterflyFloatingIterations > 0} {
    set solver [pw::Application begin EllipticSolver $butterflyDomains]

    foreach domain $butterflyDomains {
        $domain setEllipticSolverAttribute ShapeConstraint $sphereConeSurface
        for {set edgeIndex 1} {$edgeIndex <= 4} {incr edgeIndex} {
            $domain setEllipticSolverAttribute -edge $edgeIndex \
                EdgeAngleCalculation Interpolate
        }
    }

    # These entries represent the physical TriQuad interior connectors
    # on both of their adjacent domains.
    foreach domainEdge $butterflyFloatingDomainEdges {
        set domain [lindex $domainEdge 0]
        set edgeIndex [lindex $domainEdge 1]

        $domain setEllipticSolverAttribute -edge $edgeIndex \
            EdgeConstraint Floating
        $domain setEllipticSolverAttribute -edge $edgeIndex \
            EdgeAngleCalculation Orthogonal
    }

    $solver run $butterflyFloatingIterations
    $solver end
}

if {$ellipticIterations > 0} {
    set solver [pw::Application begin EllipticSolver $alignedDomains]

    foreach domain $alignedDomains {
        $domain setEllipticSolverAttribute ShapeConstraint $sphereConeSurface
        for {set edgeIndex 1} {$edgeIndex <= 4} {incr edgeIndex} {
            $domain setEllipticSolverAttribute -edge $edgeIndex \
                EdgeAngleCalculation Interpolate
        }
    }

    $solver run $ellipticIterations
    $solver end
}

set extrudedBlocks [list]
set totalExtrusionLayers 0

if {$IsExtrude} {
    set blockCreator [pw::Application begin Create]

    array set domainToBlock {}
    foreach domain $allDomains {
        set blockName [format "blk-%s" [$domain getName]]
        set block [createBlockFromStructuredDomain $domain $blockName]
        set domainToBlock($domain) $block
        lappend extrudedBlocks $block
    }

    $blockCreator end

    if {[llength $extrudedBlocks] != [llength $allDomains]} {
        error [format "Internal error: extrusion block count (%d) does not match surface domain count (%d)." \
            [llength $extrudedBlocks] [llength $allDomains]]
    }

    set extrusionSolver [pw::Application begin ExtrusionSolver $extrudedBlocks]
    $extrusionSolver setKeepFailingStep true

    set NormalKinseyBarthSmoothingForBlock \
        [normalizeIJVectorOrDefault $NormalKinseyBarthSmoothing NormalKinseyBarthSmoothing]

    if {$AutoOrientWallNormal} {
        if {$ExtrudeFlip} {
            set ExtrudeDirectionLabel "auto-oriented wall normals, then globally reversed by ExtrudeFlip=1"
        } else {
            set ExtrudeDirectionLabel "auto-oriented outward wall normals"
        }
    } else {
        set ExtrudeDirectionLabel "manual/raw Pointwise DirectionFlipped value applied uniformly"
    }

    set extrusionDirectionFlippedTrueCount 0
    set extrusionDirectionFlippedFalseCount 0

    foreach domain $allDomains {
        set block $domainToBlock($domain)
        safeSetExtrusionSolverAttribute $block NormalInitialStepSize $FirstLayerHeight 1
        safeSetExtrusionSolverAttribute $block SpacingGrowthFactor $GrowthRate(1) 1
        safeSetExtrusionSolverAttribute $block \
            NormalKinseyBarthSmoothing $NormalKinseyBarthSmoothingForBlock 0
        safeSetExtrusionSolverAttribute $block NormalVolumeSmoothing $NormalVolumeSmoothing 0

        if {$AutoOrientWallNormal} {
            if {![info exists domainOutwardFlipNeeded($domain)]} {
                error [format "Internal error: no outward-normal orientation metadata for domain %s." [$domain getName]]
            }
            # XOR: apply the per-domain outward correction, then optionally reverse all blocks.
            set directionFlippedInteger [expr {($domainOutwardFlipNeeded($domain) + $ExtrudeFlip) % 2}]
        } else {
            set directionFlippedInteger $ExtrudeFlip
        }

        if {$directionFlippedInteger} {
            set directionFlippedValue true
            incr extrusionDirectionFlippedTrueCount
        } else {
            set directionFlippedValue false
            incr extrusionDirectionFlippedFalseCount
        }

        # Explicitly set the direction on every block. This avoids depending on
        # a Pointwise default and makes mixed butterfly/aligned orientation safe.
        safeSetExtrusionSolverAttribute $block DirectionFlipped $directionFlippedValue 1
    }

    set appliedHalfSymmetryBoundaryCount 0
    set appliedShoulderEndBoundaryCount 0

    # Half-domain symmetry planes are y=0 by construction. Apply Constant Y
    # on the initial-front edges that lie on those two azimuthal boundaries.
    if {$IsAxi} {
        foreach domainEdge $halfSymmetryDomainEdges {
            set domain [lindex $domainEdge 0]
            set edgeIndex [lindex $domainEdge 1]
            set selectorHints [lindex $domainEdge 2]
            set block $domainToBlock($domain)
            setBlockExtrusionBoundaryConditionOnDomainEdge \
                $block $domain $edgeIndex $HalfDomainBoundaryConstraint 1 $selectorHints
            incr appliedHalfSymmetryBoundaryCount
        }
    }

    # The shoulder/aft end of every aligned strip is the P4 ring. It should stay
    # on the same x-plane while normal extrusion advances, so use Constant X.
    # Note: this boundary is intentionally constrained and therefore is not a
    # purely free wall-normal marching boundary.
    if {$IsShoulderEndConstraint} {
        foreach domainEdge $shoulderEndDomainEdges {
            set domain [lindex $domainEdge 0]
            set edgeIndex [lindex $domainEdge 1]
            set selectorHints [lindex $domainEdge 2]
            set block $domainToBlock($domain)
            setBlockExtrusionBoundaryConditionOnDomainEdge \
                $block $domain $edgeIndex $ShoulderEndBoundaryConstraint 1 $selectorHints
            incr appliedShoulderEndBoundaryCount
        }
    }

    for {set phase 1} {$phase <= $GrowthPhaseCount} {incr phase} {
        if {$GrowthIteration($phase) <= 0} {
            continue
        }
        foreach block $extrudedBlocks {
            safeSetExtrusionSolverAttribute $block SpacingGrowthFactor $GrowthRate($phase) 1
        }
        $extrusionSolver run $GrowthIteration($phase)
        incr totalExtrusionLayers $GrowthIteration($phase)
    }

    $extrusionSolver end
}

pw::Display resetView -Z

puts "Sphere-cone database and compact structured mesh created successfully."
puts [format "  IsAxi: %d" $IsAxi]
puts [format "  Active azimuth angle: %.1f deg" $activeAngleDegrees]
puts [format "  Full-360 circumferential cells (Nconnector): %d" $Nconnector]
puts [format "  Active circumferential cells: %d" $activeCircumferentialCells]
puts [format "  Topological circumferential sectors: %d" $topologySectorCount]
puts [format "  Cells per topology sector: %d" $cellsPerSector]
puts [format "  Butterfly domains: %d" [llength $butterflyDomains]]
puts [format "  Aligned downstream domains: %d" [llength $alignedDomains]]
puts [format "  Shoulder-end constrained edges: %d" [llength $shoulderEndDomainEdges]]
puts [format "  Total surface domains: %d" [llength $allDomains]]
puts [format "  Axial cells: nose=%d, frustum=%d, edge=%d, total=%d" \
    $NnoseAlignedCells $NfrustumCells $NedgeCells $totalAxialCells]
puts [format "  Butterfly floating iterations: %d" $butterflyFloatingIterations]
puts [format "  Aligned-strip elliptic iterations: %d" $ellipticIterations]
puts [format "  IsExtrude: %d" $IsExtrude]
if {$IsExtrude} {
    puts [format "  Extrusion source surface domains: %d / %d" [llength $extrudedBlocks] [llength $allDomains]]
    puts [format "  Extruded blocks: %d" [llength $extrudedBlocks]]
    puts [format "  First layer height: %.6e" $FirstLayerHeight]
    puts [format "  Total extrusion layers: %d" $totalExtrusionLayers]
    puts [format "  Expected extrusion-direction points: %d" [expr {$totalExtrusionLayers + 1}]]
    puts [format "  Active growth phases: %d" $GrowthPhaseCount]
    puts [format "  AutoOrientWallNormal: %d" $AutoOrientWallNormal]
    puts [format "  ExtrudeFlip: %d (%s)" $ExtrudeFlip $ExtrudeDirectionLabel]
    puts [format "  DirectionFlipped blocks: true=%d, false=%d" \
        $extrusionDirectionFlippedTrueCount $extrusionDirectionFlippedFalseCount]
    puts [format "  Normal Kinsey-Barth smoothing: %s" $NormalKinseyBarthSmoothingForBlock]
    for {set phase 1} {$phase <= $GrowthPhaseCount} {incr phase} {
        puts [format "  Growth phase %d: rate=%.6g, iterations=%d" \
            $phase $GrowthRate($phase) $GrowthIteration($phase)]
    }
    if {$IsAxi} {
        puts [format "  Half-domain extrusion boundary constraint: %s, applied edges=%d" \
            $HalfDomainBoundaryConstraint $appliedHalfSymmetryBoundaryCount]
    }
    puts [format "  Shoulder-end Constant-X constraint: %d, condition=%s, applied edges=%d" \
        $IsShoulderEndConstraint $ShoulderEndBoundaryConstraint $appliedShoulderEndBoundaryCount]
}
