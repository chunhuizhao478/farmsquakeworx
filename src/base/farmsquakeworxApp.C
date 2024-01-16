#include "farmsquakeworxApp.h"
#include "Moose.h"
#include "AppFactory.h"
#include "ModulesApp.h"
#include "MooseSyntax.h"

InputParameters
farmsquakeworxApp::validParams()
{
  InputParameters params = MooseApp::validParams();
  params.set<bool>("use_legacy_material_output") = false;
  return params;
}

farmsquakeworxApp::farmsquakeworxApp(InputParameters parameters) : MooseApp(parameters)
{
  farmsquakeworxApp::registerAll(_factory, _action_factory, _syntax);
}

farmsquakeworxApp::~farmsquakeworxApp() {}

void 
farmsquakeworxApp::registerAll(Factory & f, ActionFactory & af, Syntax & s)
{
  ModulesApp::registerAllObjects<farmsquakeworxApp>(f, af, s);
  Registry::registerObjectsTo(f, {"farmsquakeworxApp"});
  Registry::registerActionsTo(af, {"farmsquakeworxApp"});

  /* register custom execute flags, action syntax, etc. here */
}

void
farmsquakeworxApp::registerApps()
{
  registerApp(farmsquakeworxApp);
}

/***************************************************************************************************
 *********************** Dynamic Library Entry Points - DO NOT MODIFY ******************************
 **************************************************************************************************/
extern "C" void
farmsquakeworxApp__registerAll(Factory & f, ActionFactory & af, Syntax & s)
{
  farmsquakeworxApp::registerAll(f, af, s);
}
extern "C" void
farmsquakeworxApp__registerApps()
{
  farmsquakeworxApp::registerApps();
}
