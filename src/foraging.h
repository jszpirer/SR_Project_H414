#include <argos3/core/simulator/loop_functions.h>
#include <argos3/plugins/robots/foot-bot/simulator/footbot_entity.h>
#include <fstream>

using namespace argos;

class CForaging : public CLoopFunctions {

public:

   /**
    * Class constructor
    */
   CForaging();

   /**
    * Class destructor
    */
   virtual ~CForaging();

   /**
    * Initializes the experiment.
    * It is executed once at the beginning of the experiment, i.e., when ARGoS is launched.
    * @param t_tree The parsed XML tree corresponding to the <loop_functions> section.
    */
   virtual void Init(TConfigurationNode& t_tree);

   /**
    * Resets the experiment to the state it was right after Init() was called.
    * It is executed every time you press the 'reset' button in the GUI.
    */
   virtual void Reset();

   /**
    * Undoes whatever Init() did.
    * It is executed once when ARGoS has finished the experiment.
    */
   virtual void Destroy();

   /**
    * Performs actions right before a simulation step is executed.
    */
   virtual void PreStep();

   /**
    * Performs actions right after a simulation step is executed.
    */
   virtual void PostStep();

   /**
    * Performs actions right after an experiment is finalized.
    */
   virtual void PostExperiment();

   /**
    * Returns the color of the floor at the specified point on.
    * @param c_position_on_plane The position at which you want to get the color.
    * @see CColor
    */
   virtual CColor GetFloorColor(const CVector2& c_position_on_plane);

   /*
     * Return a random robot positions.
     */
   CVector3 GetRandomRobotPosition();

   /*
     * Return a random cylinder positions.
     */
   CVector3 GetRandomCylinderPosition();

private:

   /**
    * Fills into m_vecConstructionObjectsInArea
    */
   void FilterObjects();


   /*
     * Method used to reallocate the robots.
     * The position is given by the method GetRandomPosition().
     */
    void MoveRobots();

    /*
     * Method used to reallocate the objects to be foraged.
     * The position is given by the method GetRandomPosition().
     */
    void MoveCylinders();

   
private:

   /**
    * This vector contains a list of positions of objects in the construction area
    */
   std::vector<CVector3> m_vecConstructionObjectsInArea;

   bool m_bResetAll;

   CRandom::CRNG* m_pcRNG;

};
