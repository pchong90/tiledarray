# -*- mode: cmake -*-

######################
# Find Elemental
######################

include(ExternalProject)

find_package(Elemental COMPONENTS pmrrr;lapack-addons)

if(Elemental_FOUND)
  
  if(NOT TILEDARRAY_HAS_CXX11)
    message(FATAL_ERROR "Elemental requires a C++11 compatible compiler.")
  endif(NOT TILEDARRAY_HAS_CXX11)
  
  cmake_push_check_state()
  
  # Elemental compiles check
  list(APPEND CMAKE_REQUIRED_INCLUDES ${Elemental_INCLUDE_DIRS} ${MPI_INCLUDE_PATH})
  message("${Elemental_LIBRARIES}")
  list(APPEND CMAKE_REQUIRED_LIBRARIES ${LAPACK_LINKER_FLAGS} ${MPI_LINK_FLAGS}
      ${Elemental_LIBRARIES} ${LAPACK_LIBRARIES} ${MPI_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT})
  set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} ${MPI_COMPILE_FLAGS}")

  CHECK_CXX_SOURCE_COMPILES(
    "
    #include <elemental.hpp>
    using namespace elem;
    int main (int argc, char** argv){
      Initialize(argc, argv);
      mpi::Comm comm = mpi::COMM_WORLD;
      const Grid grid(comm);
      DistMatrix<double> X(grid);
      Identity(X, 16, 16);
      
      Finalize();
      return 0;
    }
    " 
    ELEMENTAL_COMPILES)

  cmake_pop_check_state()
  
  if(NOT ELEMENTAL_COMPILES)
    message(FATAL_ERROR "Could not compile Elemental test program")
  endif(NOT ELEMENTAL_COMPILES)

  set(TILEDARRAY_HAS_ELEMENTAL ${ELEMENTAL_COMPILES})
  
  # Set config variables
  list(APPEND TiledArray_CONFIG_INCLUDE_DIRS ${Elemental_INCLUDE_DIRS})
  set(TiledArray_CONFIG_LIBRARIES ${Elemental_LIBRARIES} ${TiledArray_CONFIG_LIBRARIES})
  
elseif(TA_EXPERT)

  message("** Elemetal was not found or explicitly set")
  message(FATAL_ERROR "** Downloading and building Elemental is explicitly disabled in EXPERT mode")

else()

  if(NOT DEFINED Elemental_URL)
    set(Elemental_URL https://github.com/elemental/Elemental.git)
  endif()
  message(STATUS "Will pull Elemental from ${Elemental_URL}")
  
  set(ELEMENTAL_CFLAGS "${CMAKE_CPP_FLAGS}")
  append_flags(ELEMENTAL_CFLAGS "${CMAKE_C_FLAGS}")
  set(ELEMENTAL_CXXFLAGS "${CMAKE_CPP_FLAGS}")
  append_flags(ELEMENTAL_CXXFLAGS "${CMAKE_CXX_FLAGS}")
  set(MAD_LDFLAGS "${CMAKE_EXE_LINKER_FLAGS}")
  
  if(CMAKE_BUILD_TYPE)
    string(TOLOWER ELEMENTAL_BUILD_TYPE "${CMAKE_BUILD_TYPE}")
    append_flags(ELEMENTAL_CFLAGS "${CMAKE_C_FLAGS_${ELEMENTAL_BUILD_TYPE}}")
    append_flags(ELEMENTAL_CXXFLAGS "${CMAKE_CXX_FLAGS_${ELEMENTAL_BUILD_TYPE}}")
  endif()
  
  
  # LAPACK
  append_flags(ELEMENTAL_MATH_LIBS "${LAPACK_LINKER_FLAGS} ${BLAS_LINKER_FLAGS}")
  foreach(_lib ${LAPACK_LIBRARIES} ${BLAS_LIBRARIES})
    list(APPEND ELEMENTAL_MATH_LIBS ${_lib})
  endforeach()
  
  # Set the Elemental source and build directories
  set(ELEMENTAL_SOURCE_DIR ${PROJECT_SOURCE_DIR}/external/src/elemental) 
  set(ELEMENTAL_BINARY_DIR ${PROJECT_BINARY_DIR}/external/build/elemental) 
  
  ExternalProject_Add(elemental
    PREFIX ${CMAKE_INSTALL_PREFIX}
    STAMP_DIR ${ELEMENTAL_BINARY_DIR}/stamp
   #--Download step--------------
    GIT_REPOSITORY ${Elemental_URL}
    GIT_TAG v0.84
   #--Update/Patch step----------
    UPDATE_COMMAND ""
    PATCH_COMMAND ""
   #--Configure step-------------
    SOURCE_DIR ${ELEMENTAL_SOURCE_DIR}
    TMP_DIR ${ELEMENTAL_BINARY_DIR}/tmp
    CMAKE_ARGS
        -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
        -DCMAKE_BUILD_TYPE=PureRelease
        -DMPI_C_COMPILER=${MPI_C_COMPILER}
        -DMPI_CXX_COMPILER=${MPI_CXX_COMPILER}
        -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
        -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
        -DC_FLAGS=${ELEMENTAL_CFLAGS}
        -DCXX_FLAGS=${ELEMENTAL_CXXFLAGS}
        -DMATH_LIBS=${ELEMENTAL_MATH_LIBS}
        -DCMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS}
    CMAKE_GENERATOR "Unix Makefiles"
   #--Build step-----------------
    BINARY_DIR ${ELEMENTAL_BINARY_DIR}
   #--Install step---------------
    INSTALL_COMMAND ""
    STEP_TARGETS download configure build
    )
    
  
  # Add elemental-update target that will pull updates to the Elemental source
  # from the git repository. This is done outside ExternalProject_add to prevent
  # Elemental from doing a full pull, configure, and build everytime the project
  # is built.
  add_custom_target(elemental-update
    COMMAND ${GIT_EXECUTABLE} pull --rebase origin master
    COMMAND ${CMAKE_COMMAND} -E touch_nocreate ${ELEMENTAL_BINARY_DIR}/stamp/elemental-configure
    WORKING_DIRECTORY ${ELEMENTAL_SOURCE_DIR}
    COMMENT "Updating source for 'elemental' from ${ELEMENTAL_URL}")

  # Add elemental-clean target that will delete files generated by Elemental build.
  add_custom_target(elemental-clean
    COMMAND $(MAKE) clean
    COMMAND ${CMAKE_COMMAND} -E touch_nocreate ${ELEMENTAL_BINARY_DIR}/stamp/elemental-configure
    WORKING_DIRECTORY ${ELEMENTAL_BINARY_DIR}
    COMMENT Cleaning build directory for 'elemental')

  # Since 'elemental-install' target cannot be linked to the 'install' target,
  # we will do it manually here.
  install(CODE
      "
      execute_process(
          COMMAND \"${CMAKE_MAKE_PROGRAM}\" \"install\" 
          WORKING_DIRECTORY \"${ELEMENTAL_BINARY_DIR}\"
          RESULT_VARIABLE error_code)
      if(error_code)
        message(FATAL_ERROR \"Failed to install 'elemental'\")
      endif()
      "
      )
  
  # Set the build variables
  set(Elemental_INCLUDE_DIRS "${ELEMENTAL_BINARY_DIR}/include")
  set(Elemental_LIBRARIES 
      "${ELEMENTAL_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}elemental${CMAKE_STATIC_LIBRARY_SUFFIX}"
      "${ELEMENTAL_BINARY_DIR}/external/pmrrr/${CMAKE_STATIC_LIBRARY_PREFIX}pmrrr${CMAKE_STATIC_LIBRARY_SUFFIX}")
  set(TILEDARRAY_HAS_ELEMENTAL 1)
  set(MAD_DEPENDS elemental)
  
  
  # Set config variables
  set(TiledArray_CONFIG_LIBRARIES 
      "${CMAKE_INSTALL_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}elemental${CMAKE_STATIC_LIBRARY_SUFFIX}"
      "${CMAKE_INSTALL_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}pmrrr${CMAKE_STATIC_LIBRARY_SUFFIX}"
      ${TiledArray_CONFIG_LIBRARIES})

endif()

include_directories(${Elemental_INCLUDE_DIRS})
set(TiledArray_LIBRARIES "${Elemental_LIBRARIES}" ${TiledArray_LIBRARIES})
