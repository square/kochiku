/                                        -> projects#index; listing of all of the projects
/XmlStatusReport.aspx                    -> projects#status_report; cimonitor uses this to determine if a project is currently building
/projects/web                            -> projects#show; list of all the recent builds for the Web project
/projects/web.rss                        -> projects#show; rss feed of the recent builds. Used by cimonitor
/projects/web/builds                     -> builds#create; used by Github to trigger a new build
/projects/web/builds/4                   -> builds#show; view status of all the build parts in aggregate
/projects/web/builds/4/parts/7           -> build_parts#show; view status of all the build attempts for a build part
/build_attempts/:build_attempt_id/build_artifacts -> build_artifacts#create; upload a new log file
