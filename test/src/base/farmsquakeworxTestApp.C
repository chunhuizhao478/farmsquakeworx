//* This file is part of the MOOSE framework
//* https://www.mooseframework.org
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html
#include "farmsquakeworxTestApp.h"
#include "farmsquakeworxApp.h"
#include "Moose.h"
#include "AppFactory.h"
#include "MooseSyntax.h"

InputParameters
farmsquakeworxTestApp::validParams()
{
  InputParameters params = farmsquakeworxApp::validParams();
  params.set<bool>("use_legacy_material_output") = false;
  return params;
}

farmsquakeworxTestApp::farmsquakeworxTestApp(InputParameters parameters) : MooseApp(parameters)
{
  farmsquakeworxTestApp::registerAll(
      _factory, _action_factory, _syntax, getParam<bool>("allow_test_objects"));
}

farmsquakeworxTestApp::~farmsquakeworxTestApp() {}

void
farmsquakeworxTestApp::registerAll(Factory & f, ActionFactory & af, Syntax & s, bool use_test_objs)
{
  farmsquakeworxApp::registerAll(f, af, s);
  if (use_test_objs)
  {
    Registry::registerObjectsTo(f, {"farmsquakeworxTestApp"});
    Registry::registerActionsTo(af, {"farmsquakeworxTestApp"});
  }
}

void
farmsquakeworxTestApp::registerApps()
{
  registerApp(farmsquakeworxApp);
  registerApp(farmsquakeworxTestApp);
}

/***************************************************************************************************
 *********************** Dynamic Library Entry Points - DO NOT MODIFY ******************************
 **************************************************************************************************/
// External entry point for dynamic application loading
extern "C" void
farmsquakeworxTestApp__registerAll(Factory & f, ActionFactory & af, Syntax & s)
{
  farmsquakeworxTestApp::registerAll(f, af, s);
}
extern "C" void
farmsquakeworxTestApp__registerApps()
{
  farmsquakeworxTestApp::registerApps();
}
