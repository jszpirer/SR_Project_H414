#include "foraging.h"

#include <argos3/plugins/simulator/entities/cylinder_entity.h>

#include <algorithm>
#include <cstring>
#include <cerrno>

/****************************************/
/****************************************/

static const Real OBJECT_RADIUS            = 0.1f;
static const Real OBJECT_DIAMETER          = OBJECT_RADIUS * 2.0f;

static const Real CONSTRUCTION_AREA_MIN_X  = 2.69f;
static const Real CONSTRUCTION_AREA_MAX_X  = 3.69f;
static const Real CONSTRUCTION_AREA_MIN_Y  = -2.69f;
static const Real CONSTRUCTION_AREA_MAX_Y  = 2.69f;

/****************************************/
/****************************************/

CForaging::CForaging() :
   m_bResetAll(false),
   m_pcRNG(NULL) {
}

/****************************************/
/****************************************/

CForaging::~CForaging() {
   /* Nothing to do */
}

/****************************************/
/****************************************/

void CForaging::Init(TConfigurationNode& t_tree) {
   try {
      TConfigurationNode& tForaging = GetNode(t_tree, "params");

      /* Get the cache area configuration from XML */
      GetNodeAttribute(tForaging, "reset_all", m_bResetAll);
      
   }
   catch(CARGoSException& ex) {
      THROW_ARGOSEXCEPTION_NESTED("Error parsing loop functions!", ex);
   }

   m_pcRNG = CRandom::CreateRNG("argos");

}

/****************************************/
/****************************************/

void CForaging::Reset() {
   /* Nothing to do */
   m_vecConstructionObjectsInArea.clear();

   if (m_bResetAll)
   {
      MoveRobots();
      MoveCylinders();
   }
}

/****************************************/
/****************************************/

void CForaging::Destroy() {
   /* Nothing to do */
}

/****************************************/
/****************************************/

void CForaging::PreStep() {
   /* Nothing to do */
}

/****************************************/
/****************************************/

void CForaging::PostStep() {
FilterObjects();
  /* Output a line for this step */
  LOG << "Objects: " << m_vecConstructionObjectsInArea.size() << std::endl;

}

/****************************************/
/****************************************/

void CForaging::PostExperiment() {
  FilterObjects();
  /* Output a line for this step */
  LOG << "Objects: " << m_vecConstructionObjectsInArea.size() << std::endl;
}

/****************************************/
/****************************************/

CColor CForaging::GetFloorColor(const CVector2& c_position_on_plane) {
   /* Check if the given point is within the foraging area */
   if(c_position_on_plane.GetX() >= CONSTRUCTION_AREA_MIN_X &&
      c_position_on_plane.GetX() <= CONSTRUCTION_AREA_MAX_X &&
      c_position_on_plane.GetY() >= CONSTRUCTION_AREA_MIN_Y &&
      c_position_on_plane.GetY() <= CONSTRUCTION_AREA_MAX_Y) {
      /* Yes, it is - return black */
      return CColor::BLACK;
   }

   /* No, it isn't - return white */
   //std::cout << "White color" << std::endl;
   return CColor::WHITE;
}

/****************************************/
/****************************************/

void CForaging::FilterObjects() {
   /* Clear list of positions of objects in construction area */
   m_vecConstructionObjectsInArea.clear();

   /* Get the list of cylinders from the ARGoS space */
   CSpace::TMapPerType& tCylinderMap = GetSpace().GetEntitiesByType("cylinder");
   /* Go through the list and collect data */
   CCylinderEntity* pcCylinder;
   for(CSpace::TMapPerType::iterator it = tCylinderMap.begin();
       it != tCylinderMap.end();
       ++it) {
      /* Get a reference to the object */     
      pcCylinder = any_cast<CCylinderEntity*>(it->second);
      //CEmbodiedEntity& cBody = any_cast<CCylinderEntity*>(it->second)->GetEmbodiedEntity();
      /* Check if object is in target area */
      if(pcCylinder->GetEmbodiedEntity().GetOriginAnchor().Position.GetX() > CONSTRUCTION_AREA_MIN_X &&
         pcCylinder->GetEmbodiedEntity().GetOriginAnchor().Position.GetX() < CONSTRUCTION_AREA_MAX_X &&
         pcCylinder->GetEmbodiedEntity().GetOriginAnchor().Position.GetY() > CONSTRUCTION_AREA_MIN_Y &&
         pcCylinder->GetEmbodiedEntity().GetOriginAnchor().Position.GetY() < CONSTRUCTION_AREA_MAX_Y) {
         /* Yes, it is */
         /* Add it to the list */
         m_vecConstructionObjectsInArea.push_back(pcCylinder->GetEmbodiedEntity().GetOriginAnchor().Position);
         pcCylinder->GetLEDEquippedEntity().SetAllLEDsColors(CColor::BLUE);
         pcCylinder->GetLEDEquippedEntity().Update();
      }
      else {
         pcCylinder->GetLEDEquippedEntity().SetAllLEDsColors(CColor::RED);
         pcCylinder->GetLEDEquippedEntity().Update();       
      }
   }

}

/****************************************/
/****************************************/

void CForaging::MoveRobots() {
  CFootBotEntity* pcFootBot;
  bool bPlaced = false;
  UInt32 unTrials;
  CSpace::TMapPerType& tFootBotMap = GetSpace().GetEntitiesByType("foot-bot");
  for (CSpace::TMapPerType::iterator it = tFootBotMap.begin(); it != tFootBotMap.end(); ++it) {
    pcFootBot = any_cast<CFootBotEntity*>(it->second);
    // Choose position at random
    unTrials = 0;
    do {
       ++unTrials;
       CVector3 cFootBotPosition = GetRandomRobotPosition();
       bPlaced = MoveEntity(pcFootBot->GetEmbodiedEntity(),
                            cFootBotPosition,
                            CQuaternion().FromEulerAngles(m_pcRNG->Uniform(CRange<CRadians>(CRadians::ZERO,CRadians::TWO_PI)),
                            CRadians::ZERO,CRadians::ZERO),false);
    } while(!bPlaced && unTrials < 1000);
    if(!bPlaced) {
       THROW_ARGOSEXCEPTION("Can't place robot");
    }
  }
}

/****************************************/
/****************************************/

void CForaging::MoveCylinders() {
  CCylinderEntity* pcCylinder;
  bool bPlaced = false;
  UInt32 unTrials;
  CSpace::TMapPerType& tCylinderMap = GetSpace().GetEntitiesByType("cylinder");
  for (CSpace::TMapPerType::iterator it = tCylinderMap.begin(); it != tCylinderMap.end(); ++it) {
    pcCylinder = any_cast<CCylinderEntity*>(it->second);
    // Choose position at random
    unTrials = 0;
    do {
       ++unTrials;
       CVector3 cCylinderPosition = GetRandomCylinderPosition();
       bPlaced = MoveEntity(pcCylinder->GetEmbodiedEntity(),
                            cCylinderPosition,
                            CQuaternion().FromEulerAngles(m_pcRNG->Uniform(CRange<CRadians>(CRadians::ZERO,CRadians::TWO_PI)),
                            CRadians::ZERO,CRadians::ZERO),false);
    } while(!bPlaced && unTrials < 1000);
    if(!bPlaced) {
       THROW_ARGOSEXCEPTION("Can't place cylinder");
    }
  }
}

/****************************************/
/****************************************/

CVector3 CForaging::GetRandomRobotPosition() {
  Real temp;
  Real fPoseX = m_pcRNG->Uniform(CRange<Real>(-2.0f, 2.0f));
  Real fPoseY = m_pcRNG->Uniform(CRange<Real>(-3.0f, 3.0f));

  return CVector3(fPoseX, fPoseY, 0);
}

/****************************************/
/****************************************/

CVector3 CForaging::GetRandomCylinderPosition() {
  Real temp;
  Real fPoseX = m_pcRNG->Uniform(CRange<Real>(-4.0f, -2.5f));
  Real fPoseY = m_pcRNG->Uniform(CRange<Real>(-3.0f, 3.0f));

  return CVector3(fPoseX, fPoseY, 0);
}

/****************************************/
/****************************************/

/* Register this loop functions into the ARGoS plugin system */
REGISTER_LOOP_FUNCTIONS(CForaging, "foraging");
