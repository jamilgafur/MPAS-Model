! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the
! LICENSE file
! distributed with this code, or at
! http://mpas-dev.github.com/license.html
!
!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
!
!  ocn_init_vertical_advection
!
!> \brief MPAS ocean initialize case -- CVMix Unit Test
!> WSwSBF means Wind Stress with Surface Buoyancy Forcing
!> \author Todd Ringler
!> \date   04/23/2015
!> \details
!>  This module contains the routines for initializing the
!>  the cvmix WSwSBF unit test configuration. This in a
!>  single column configuration
!
!-----------------------------------------------------------------------

module ocn_init_vertical_advection

   use mpas_kind_types
   use mpas_io_units
   use mpas_derived_types
   use mpas_pool_routines
   use mpas_constants

   use ocn_init_cell_markers
   use ocn_init_vertical_grids

   implicit none
   private
   save

   !--------------------------------------------------------------------
   !
   ! Public parameters
   !
   !--------------------------------------------------------------------

   !--------------------------------------------------------------------
   !
   ! Public member functions
   !
   !--------------------------------------------------------------------

   public :: ocn_init_setup_vertical_advection, &
             ocn_init_validate_vertical_advection

   !--------------------------------------------------------------------
   !
   ! Private module variables
   !
   !--------------------------------------------------------------------

!***********************************************************************

contains

!***********************************************************************
!
!  routine ocn_init_setup_vertical_advection
!
!> \brief   Setup for cvmix WSwSBF unit test configuration
!> \author  Todd Ringler
!> \date    04/23/2015
!> \details
!>  This routine sets up the initial conditions for the cvmix WSwSBF
!unit test configuration.
!
!-----------------------------------------------------------------------

   subroutine ocn_init_setup_vertical_advection(domain, iErr)!{{{

   !--------------------------------------------------------------------

      type (domain_type), intent(inout) :: domain
      integer, intent(out) :: iErr
      real (kind=RKIND) :: temperature, salinity

      type (block_type), pointer :: block_ptr

      type (mpas_pool_type), pointer :: meshPool, verticalMeshPool,statePool
      type (mpas_pool_type), pointer :: diagnosticsPool, forcingPool

      type (mpas_pool_type), pointer :: tracersPool, &
                                        tracersSurfaceRestoringFieldsPool,&
                                        tracersInteriorRestoringFieldsPool

      integer, pointer :: nVertLevels, nVertLevelsP1, nCellsSolve,nEdgesSolve, nEdge, nVerticesSolve
      integer, pointer :: index_temperature, index_salinity,index_tracer1

      integer, dimension(:), pointer :: maxLevelCell
      real (kind=RKIND), dimension(:), pointer :: refBottomDepth,refZMid, vertCoordMovementWeights
      real (kind=RKIND), dimension(:), pointer :: windStressZonal,windStressMeridional
      real (kind=RKIND), dimension(:), pointer :: latentHeatFlux,sensibleHeatFlux, shortWaveHeatFlux
      real (kind=RKIND), dimension(:), pointer :: evaporationFlux,rainFlux
      real (kind=RKIND), dimension(:), pointer :: salinityRestore,bottomDepth, angleEdge
      real (kind=RKIND), dimension(:), pointer :: fCell, fEdge, fVertex,xCell, yCell
      real (kind=RKIND), dimension(:, :), pointer :: layerThickness,restingThickness, normalVelocity, vertVelocityTop
      real (kind=RKIND), dimension(:, :, :), pointer :: activeTracers,debugTracers
      real (kind=RKIND), dimension(:, :), pointer ::activeTracersPistonVelocity, activeTracersSurfaceRestoringValue
      real (kind=RKIND), dimension(:, :, :), pointer ::activeTracersInteriorRestoringValue, activeTracersInteriorRestoringRate

      real (kind=RKIND), dimension(:), pointer :: interfaceLocations

      integer :: iCell, iEdge, iVertex, k, kML

      real (kind=RKIND) :: BLdepth, r_pt

      character (len=StrKIND), pointer :: config_init_configuration, &
                                          config_vertical_advection_vertical_grid

      integer, pointer ::                 config_vertical_advection_vert_levels

      real (kind=RKIND), pointer ::config_vertical_advection_surface_temperature, &
                                   config_vertical_advection_surface_salinity,&
                                          config_vertical_advection_surface_restoring_temperature,&
                                          config_vertical_advection_surface_restoring_salinity,&
                                          config_vertical_advection_temperature_piston_velocity,&
                                          config_vertical_advection_salinity_piston_velocity,&
                                          config_vertical_advection_sensible_heat_flux,&
                                          config_vertical_advection_latent_heat_flux,&
                                          config_vertical_advection_shortwave_heat_flux,&
                                          config_vertical_advection_rain_flux, &
                                          config_vertical_advection_evaporation_flux,&
                                          config_vertical_advection_interior_temperature_restoring_rate,&
                                          config_vertical_advection_interior_salinity_restoring_rate,&
                                          config_vertical_advection_temperature_gradient,&
                                          config_vertical_advection_salinity_gradient,&
                                          config_vertical_advection_bottom_depth,&
                                          config_vertical_advection_max_windstress,&
                                          config_vertical_advection_coriolis_parameter,&
                                          config_vertical_advection_temperature_gradient_mixed_layer,&
                                          config_vertical_advection_salinity_gradient_mixed_layer,&
                                          config_vertical_advection_mixed_layer_depth_temperature,&
                                          config_vertical_advection_mixed_layer_depth_salinity,&
                                          config_vertical_advection_mixed_layer_temperature_change,&
                                          config_vertical_advection_mixed_layer_salinity_change,&
                                          config_vertical_advection_zonalC, &
                                          config_vertical_advection_meridionalC,&
                                          x_cent , y_cent,layer_1, layer_2, vertVelocityTopVar, &
                                          config_tracer_radius
      ! assume no error
      iErr = 0

      ! get and test if this is the configuration specified
      call mpas_pool_get_config(domain % configs,'config_init_configuration', config_init_configuration)
      if(config_init_configuration .ne. trim('vertical_advection')) return

      ! build the vertical grid
      ! intent(out) is interfaceLocations. An array ranging from 0 to 1
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_vertical_grid', config_vertical_advection_vertical_grid)
      call mpas_pool_get_dimension(domain % blocklist % dimensions,'nVertLevelsP1', nVertLevelsP1)
      allocate(interfaceLocations(nVertLevelsP1))
      call ocn_generate_vertical_grid(config_vertical_advection_vertical_grid,interfaceLocations)

      ! load the remaining configuration parameters
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_surface_temperature', &
                                config_vertical_advection_surface_temperature)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_surface_salinity', config_vertical_advection_surface_salinity)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_surface_restoring_temperature', &
                                config_vertical_advection_surface_restoring_temperature)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_surface_restoring_salinity', &
                                config_vertical_advection_surface_restoring_salinity)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_temperature_piston_velocity', &
                                config_vertical_advection_temperature_piston_velocity)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_salinity_piston_velocity', &
                                config_vertical_advection_salinity_piston_velocity)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_sensible_heat_flux',config_vertical_advection_sensible_heat_flux)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_latent_heat_flux', config_vertical_advection_latent_heat_flux)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_shortwave_heat_flux', &
                                config_vertical_advection_shortwave_heat_flux)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_rain_flux', config_vertical_advection_rain_flux)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_evaporation_flux', config_vertical_advection_evaporation_flux)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_interior_temperature_restoring_rate', &
                                config_vertical_advection_interior_temperature_restoring_rate)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_interior_salinity_restoring_rate', &
                                config_vertical_advection_interior_salinity_restoring_rate)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_temperature_gradient', &
                                config_vertical_advection_temperature_gradient)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_salinity_gradient',config_vertical_advection_salinity_gradient)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_bottom_depth', config_vertical_advection_bottom_depth)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_max_windstress', config_vertical_advection_max_windstress)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_coriolis_parameter',config_vertical_advection_coriolis_parameter)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_temperature_gradient_mixed_layer', &
                config_vertical_advection_temperature_gradient_mixed_layer)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_salinity_gradient_mixed_layer', &
                config_vertical_advection_salinity_gradient_mixed_layer)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_mixed_layer_depth_temperature', &
                config_vertical_advection_mixed_layer_depth_temperature)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_mixed_layer_depth_salinity', &
                config_vertical_advection_mixed_layer_depth_salinity)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_mixed_layer_temperature_change', &
                config_vertical_advection_mixed_layer_temperature_change)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_mixed_layer_salinity_change', &
                config_vertical_advection_mixed_layer_salinity_change)
     !------------
     ! Jamil  edits
     !-----------


      call mpas_pool_get_config(domain % configs,'config_vertical_advection_zonalC', config_vertical_advection_zonalC)
      call mpas_pool_get_config(domain % configs,'config_vertical_advection_meridionalC', config_vertical_advection_meridionalC)
      call mpas_pool_get_config(domain % configs,'config_tracer_radius', config_tracer_radius)
      call mpas_pool_get_config(domain % configs, 'y_cent', y_cent)
      call mpas_pool_get_config(domain % configs, 'layer_1', layer_1)
      call mpas_pool_get_config(domain % configs, 'layer_2', layer_2)
      call mpas_pool_get_config(domain % configs, 'x_cent', x_cent)
      call mpas_pool_get_config(domain % configs, 'vertVeclocityTopVar', vertVelocityTopVar )

     !----------------
     ! end Jamil edits
     !---------------

      ! load data that required to initialize the ocean simulation
      block_ptr => domain % blocklist
      do while(associated(block_ptr))
        call mpas_pool_get_subpool(block_ptr % structs, 'mesh',meshPool)
        call mpas_pool_get_subpool(block_ptr % structs, 'verticalMesh',verticalMeshPool)
        call mpas_pool_get_subpool(block_ptr % structs, 'state',statePool)
        call mpas_pool_get_subpool(block_ptr % structs, 'diagnostics',diagnosticsPool)
        call mpas_pool_get_subpool(block_ptr % structs, 'forcing',forcingPool)

        call mpas_pool_get_subpool(statePool, 'tracers', tracersPool)
        call mpas_pool_get_subpool(forcingPool,'tracersSurfaceRestoringFields', tracersSurfaceRestoringFieldsPool)
        call mpas_pool_get_subpool(forcingPool,'tracersInteriorRestoringFields', tracersInteriorRestoringFieldsPool)

        call mpas_pool_get_dimension(meshPool, 'nVertLevels',nVertLevels)
        call mpas_pool_get_dimension(meshPool, 'nCellsSolve',nCellsSolve)
        call mpas_pool_get_dimension(meshPool, 'nEdge', nEdge)
        call mpas_pool_get_dimension(meshPool, 'nEdgesSolve',nEdgesSolve)
        call mpas_pool_get_dimension(meshPool, 'nVerticesSolve',nVerticesSolve)

        call mpas_pool_get_dimension(tracersPool, 'index_temperature',index_temperature)
        call mpas_pool_get_dimension(tracersPool, 'index_salinity',index_salinity)
        call mpas_pool_get_dimension(tracersPool, 'index_tracer1',index_tracer1)

        call mpas_pool_get_array(meshPool, 'refBottomDepth',refBottomDepth)
        call mpas_pool_get_array(meshPool, 'vertCoordMovementWeights',vertCoordMovementWeights)
        call mpas_pool_get_array(meshPool, 'maxLevelCell', maxLevelCell)
        call mpas_pool_get_array(meshPool, 'bottomDepth', bottomDepth)
        call mpas_pool_get_array(meshPool, 'angleEdge', angleEdge)
        call mpas_pool_get_array(statePool, 'normalVelocity',normalVelocity)
        
        call mpas_pool_get_array(meshPool, 'fCell', fCell)
        call mpas_pool_get_array(meshPool, 'fEdge', fEdge)
        call mpas_pool_get_array(meshPool, 'fVertex', fVertex)
        call mpas_pool_get_array(meshPool, 'xCell', xCell)
        call mpas_pool_get_array(meshPool, 'yCell', yCell)


        call mpas_pool_get_array(verticalMeshPool, 'refZMid', refZMid)
        call mpas_pool_get_array(verticalMeshPool, 'restingThickness',restingThickness)

        call mpas_pool_get_array(tracersPool, 'activeTracers',activeTracers, 1)
        call mpas_pool_get_array(tracersPool, 'debugTracers',debugTracers, 1)
        call mpas_pool_get_array(statePool, 'layerThickness',layerThickness, 1)

        call mpas_pool_get_array(forcingPool, 'windStressZonal',windStressZonal, 1)
        call mpas_pool_get_array(forcingPool, 'windStressMeridional',windStressMeridional, 1)
        call mpas_pool_get_array(tracersSurfaceRestoringFieldsPool,'activeTracersPistonVelocity', activeTracersPistonVelocity, 1)
        call mpas_pool_get_array(tracersSurfaceRestoringFieldsPool,'activeTracersSurfaceRestoringValue', &
                                 activeTracersSurfaceRestoringValue, 1)
        call mpas_pool_get_array(tracersInteriorRestoringFieldsPool,'activeTracersInteriorRestoringRate', &
                                 activeTracersInteriorRestoringRate, 1)
        call mpas_pool_get_array(tracersInteriorRestoringFieldsPool,'activeTracersInteriorRestoringValue', &
                                 activeTracersInteriorRestoringValue, 1)
        call mpas_pool_get_array(forcingPool, 'latentHeatFlux',latentHeatFlux)
        call mpas_pool_get_array(forcingPool, 'sensibleHeatFlux',sensibleHeatFlux)
        call mpas_pool_get_array(forcingPool, 'shortWaveHeatFlux',shortWaveHeatFlux)
        call mpas_pool_get_array(forcingPool, 'evaporationFlux',evaporationFlux)
        call mpas_pool_get_array(forcingPool, 'rainFlux', rainFlux)

        ! JAMIL NOTE: adding vertVelcoityTop to the code
        call mpas_pool_get_array(diagnosticsPool, 'vertVelocityTop', vertVelocityTop)
        ! Set refBottomDepth and refBottomDepthTopOfCell
        do k = 1, nVertLevels
           refBottomDepth(k) = config_vertical_advection_bottom_depth *interfaceLocations(k+1)
           refZMid(k) = - 0.5_RKIND * config_vertical_advection_bottom_depth *(interfaceLocations(k) + interfaceLocations(k+1))
        end do

        ! Set vertCoordMovementWeights
        vertCoordMovementWeights(:) = 1.0_RKIND
        debugTracers(:,:,:) = 0.0_RKIND
          
        do iCell = 1, nCellsSolve

           if ( associated(debugTracers) ) then
            ! generates the region inside the circle
            ! r_pt = sqrt((xCell(iCell) - x_cent) ** 2 + (yCell(iCell)- y_cent)**2)
            ! if inside the region of the circle then set inside tracer to 1
            ! if (r_pt < config_tracer_radius) then
               ! JAMIL NOTE: 1 is for hortizontal advection: shape of debugTracers
               ! is 1 100 10001 however in order to test out the output for simple
               ! chages (see 2) no output is generated, just a purple screen.
               ! leaving default to what is expected after talks with luke
               !  1) debugTracers(index_tracer1, :, iCell) = 1.0_RKIND
               !  2) debugTracers(index_tracer1, int(1):int(99), iCell) = 1.0_RKIND
               debugTracers(:, int(layer_1):int(layer_2), iCell) = 1.0_RKIND
            ! endif
          endif
          ! JAMIL NOTE: using  shared/mpas_ocn_diagnostics.F as a reference
          ! print *, associated(vertVelocityTop)
          ! output: -364690528          32
          ! I think I am allocating vertVelcoityTop wrong? 
          ! vertVelocityTop(:, iCell) = vertVelocityTopVar
        


           if(associated(activeTracers) ) then

           ! Loop from surface through surface layer depth
           k=1

           do while (k .le. nVertLevels .and. refZMid(k) > -config_vertical_advection_mixed_layer_depth_temperature)
              temperature = config_vertical_advection_surface_temperature +refZMid(k) *  &
                            config_vertical_advection_temperature_gradient_mixed_layer
              activeTracers(index_temperature, k, iCell) = temperature
              k = k + 1
           enddo

           ! the value of k is now the first layer below the surface
           ! layer
           if ( k > 1 ) then
              temperature = activeTracers(index_temperature, k-1, iCell) + config_vertical_advection_mixed_layer_temperature_change
              activeTracers(index_temperature, k, iCell) = temperature
              BLdepth = refZMid(k)
           else
              activeTracers(index_temperature, k, iCell) = config_vertical_advection_surface_temperature
              BLdepth = 0.0_RKIND
           endif

           ! find the first level below the mixed layer
           kML = k + 1

           ! now loop from the bottom of the mixed layer thru to the
           ! bottom of the domain
           do k = kML, nVertLevels
              temperature = activeTracers(index_temperature, kML-1, iCell) + (refZMid(k) - BLdepth) * &
              config_vertical_advection_temperature_gradient
              activeTracers(index_temperature, k, iCell) = temperature
           enddo

           !
           ! next compute the salinity profile
           !

           ! Loop from surface through surface layer depth
           k=1
           do while (k .le. nVertLevels .and. refZMid(k) > - config_vertical_advection_mixed_layer_depth_salinity)
              salinity = config_vertical_advection_surface_salinity + refZMid(k) * config_vertical_advection_salinity_gradient_mixed_layer
              activeTracers(index_salinity, k, iCell) = salinity
              k = k + 1
           enddo

           ! the value of k is now the first layer below the surface
           ! layer
            if ( k > 1 ) then
               salinity = activeTracers(index_salinity, k-1, iCell) + config_vertical_advection_mixed_layer_salinity_change
               activeTracers(index_salinity, k, iCell) = salinity
               BLdepth = refZMid(k)
            else
               activeTracers(index_salinity, k, iCell) = config_vertical_advection_surface_salinity
               BLdepth = 0.0_RKIND
            endif

            ! find the first level below the mixed layer
            kML = k + 1

            ! now loop from the bottom of the mixed layer thru to the
            ! bottom of the domain
            do k = kML, nVertLevels
               salinity = activeTracers(index_salinity, kML-1, iCell) + (refZMid(k) - BLdepth) *  &
               config_vertical_advection_salinity_gradient
               activeTracers(index_salinity, k, iCell) = salinity
            enddo

        endif ! if (associated(activeTracer))

        ! as a place holder, have some debug tracer in the top few
        ! layers and zero below


        ! Set layerThickness
        do k = 1, nVertLevels
           layerThickness(k, iCell) = config_vertical_advection_bottom_depth * (interfaceLocations(k+1) - interfaceLocations(k))
           restingThickness(k, iCell) = layerThickness(k, iCell)
        end do

        ! Set surface temperature restoring value and rate
        ! Value in units of C, piston velocity in units of m/s
        if ( associated(activeTracersSurfaceRestoringValue) ) then
           activeTracersSurfaceRestoringValue(index_temperature, iCell) = config_vertical_advection_surface_restoring_temperature
        end if
        if ( associated(activeTracersPistonVelocity) ) then
           activeTracersPistonVelocity(index_temperature, iCell) = config_vertical_advection_temperature_piston_velocity
        end if

        ! Set surface salinity restoring value and rate
        ! Value in units of PSU, piston velocity in units of m/s
        if ( associated(activeTracersSurfaceRestoringValue) ) then
           activeTracersSurfaceRestoringValue(index_salinity, iCell) = config_vertical_advection_surface_restoring_salinity
        end if
        if ( associated(activeTracersPistonVelocity) ) then
           activeTracersPistonVelocity(index_salinity, iCell) = config_vertical_advection_salinity_piston_velocity
        end if

        ! Set sensible heat flux
        sensibleHeatFlux(iCell) = config_vertical_advection_sensible_heat_flux

        ! Set latent heat flux
        latentHeatFlux(iCell) = config_vertical_advection_latent_heat_flux

        ! Set shortwave heat flux
        shortWaveHeatFlux(iCell) = config_vertical_advection_shortwave_heat_flux

        ! Set precipation and evaporation
        rainFlux(iCell) = config_vertical_advection_rain_flux
        evaporationFlux(iCell) = config_vertical_advection_evaporation_flux

        ! Set interior temperature restoring value and rate
        do k = 1, nVertLevels
           if ( associated(activeTracersInteriorRestoringValue) ) then
              activeTracersInteriorRestoringValue(index_temperature, k, iCell) = activeTracers(index_temperature, k, iCell)
           end if
           if ( associated(activeTracersInteriorRestoringRate) ) then
              activeTracersInteriorRestoringRate(index_temperature, k, iCell) = &
                                config_vertical_advection_interior_temperature_restoring_rate
           end if
        enddo

        ! Set interior salinity restoring value and rate
        do k = 1, nVertLevels
           if ( associated(activeTracersInteriorRestoringValue) ) then
              activeTracersInteriorRestoringValue(index_salinity, k, iCell) = activeTracers(index_salinity, k, iCell)
           end if
           if ( associated(activeTracersInteriorRestoringRate) ) then
              activeTracersInteriorRestoringRate(index_salinity, k,iCell) = config_vertical_advection_interior_salinity_restoring_rate
           end if
        enddo

        ! Set Coriolis parameter
        fCell(iCell) = config_vertical_advection_coriolis_parameter

        ! Set bottomDepth
        bottomDepth(iCell) = config_vertical_advection_bottom_depth

        ! Set maxLevelCell
        maxLevelCell(iCell) = nVertLevels

     end do  ! do iCell

     do iCell = 1, nCellsSolve
        windStressZonal(iCell) = config_vertical_advection_max_windstress
        windStressMeridional(iCell) = 0.0_RKIND
     enddo

     do iEdge = 1, nEdgesSolve
        fEdge(iEdge) = config_vertical_advection_coriolis_parameter
     end do

     do iVertex=1, nVerticesSolve
        fVertex(iVertex) = config_vertical_advection_coriolis_parameter
     end do

     block_ptr => block_ptr % next
   end do
!--------------
! Jamil edits for adding
! the C variable
!--------------
!    do iEdge=1, nEdgesSolve
!      normalVelocity(:, iEdge) = ( cos(angleEdge(iEdge)) * config_vertical_advection_zonalC) + ( sin(angleEdge(iEdge)) * config_vertical_advection_meridionalC )
!    enddo
!--------------
! end Jamil edit
!--------------

   deallocate(interfaceLocations)

   !--------------------------------------------------------------------

   end subroutine ocn_init_setup_vertical_advection!}}}

!***********************************************************************
!
!  routine ocn_init_validate_vertical_advection
!
!> \brief   Validation for CVMix WSwSBF mixing unit test case
!> \author  Doug Jacobsen
!> \date    04/01/2015
!> \details
!>  This routine validates the configuration options for the CVMix
!WSwSBF mixing unit test configuration.
!
!-----------------------------------------------------------------------

   subroutine ocn_init_validate_vertical_advection(configPool, packagePool,iocontext, iErr)!{{{

   !--------------------------------------------------------------------

      type (mpas_pool_type), intent(inout) :: configPool
      type (mpas_pool_type), intent(inout) :: packagePool
      type (mpas_io_context_type), intent(inout) :: iocontext

      integer, intent(out) :: iErr

      character (len=StrKIND), pointer :: config_init_configuration
      integer, pointer :: config_vert_levels,config_vertical_advection_vert_levels

      iErr = 0

      call mpas_pool_get_config(configPool, 'config_init_configuration',config_init_configuration)

      if(config_init_configuration .ne. trim('vertical_advection')) return

      call mpas_pool_get_config(configPool, 'config_vert_levels',config_vert_levels)
      call mpas_pool_get_config(configPool,'config_vertical_advection_vert_levels', config_vertical_advection_vert_levels)

      if(config_vert_levels <= 0 .and. config_vertical_advection_vert_levels > 0) then
         config_vert_levels = config_vertical_advection_vert_levels
      else if(config_vert_levels <= 0) then
         call mpas_log_write( 'Validation failed for CVMix WSwSBF unittest case. Not given a usable value for ' &
                          // 'vertical levels.', MPAS_LOG_CRIT)
         iErr = 1
      end if

   !--------------------------------------------------------------------

   end subroutine ocn_init_validate_vertical_advection!}}}

!***********************************************************************

end module ocn_init_vertical_advection

!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
! vim: foldmethod=marker
