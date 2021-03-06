!> Provides a transparent unit rescaling type to facilitate dimensional consistency testing
module MOM_unit_scaling

! This file is part of MOM6. See LICENSE.md for the license.

use MOM_error_handler, only : MOM_error, MOM_mesg, FATAL
use MOM_file_parser, only : get_param, log_param, log_version, param_file_type

implicit none ; private

public unit_scaling_init, unit_scaling_end, fix_restart_unit_scaling

!> Describes various unit conversion factors
type, public :: unit_scale_type
  real :: m_to_Z !< A constant that translates distances in meters to the units of depth.
  real :: Z_to_m !< A constant that translates distances in the units of depth to meters.
  real :: m_to_L !< A constant that translates lengths in meters to the units of horizontal lengths.
  real :: L_to_m !< A constant that translates lengths in the units of horizontal lengths to meters.
  real :: s_to_T !< A constant that time intervals in seconds to the units of time.
  real :: T_to_s !< A constant that the units of time to seconds.

  ! These are useful combinations of the fundamental scale conversion factors above.
  real :: Z_to_L !< Convert vertical distances to lateral lengths
  real :: L_to_Z !< Convert vertical distances to lateral lengths
  real :: L_T_to_m_s !< Convert lateral velocities from L T-1 to m s-1.
  real :: m_s_to_L_T !< Convert lateral velocities from m s-1 to L T-1.
  real :: L_T2_to_m_s2 !< Convert lateral accelerations from L T-2 to m s-2.
  real :: Z2_T_to_m2_s !< Convert vertical diffusivities from Z2 T-1 to m2 s-1.
  real :: m2_s_to_Z2_T !< Convert vertical diffusivities from m2 s-1 to Z2 T-1.

  ! These are used for changing scaling across restarts.
  real :: m_to_Z_restart = 0.0 !< A copy of the m_to_Z that is used in restart files.
  real :: m_to_L_restart = 0.0 !< A copy of the m_to_L that is used in restart files.
  real :: s_to_T_restart = 0.0 !< A copy of the s_to_T that is used in restart files.
end type unit_scale_type

contains

!> Allocates and initializes the ocean model unit scaling type
subroutine unit_scaling_init( param_file, US )
  type(param_file_type), intent(in) :: param_file !< Parameter file handle/type
  type(unit_scale_type), pointer    :: US         !< A dimensional unit scaling type

  ! This routine initializes a unit_scale_type structure (US).

  ! Local variables
  integer :: Z_power, L_power, T_power
  real    :: Z_rescale_factor, L_rescale_factor, T_rescale_factor
  ! This include declares and sets the variable "version".
# include "version_variable.h"
  character(len=16) :: mdl = "MOM_unit_scaling"

  if (associated(US)) call MOM_error(FATAL, &
     'unit_scaling_init: called with an associated US pointer.')
  allocate(US)

  ! Read all relevant parameters and write them to the model log.
  call log_version(param_file, mdl, version, &
                   "Parameters for doing unit scaling of variables.")
  call get_param(param_file, mdl, "Z_RESCALE_POWER", Z_power, &
                 "An integer power of 2 that is used to rescale the model's "//&
                 "intenal units of depths and heights.  Valid values range from -300 to 300.", &
                 units="nondim", default=0, debuggingParam=.true.)
  call get_param(param_file, mdl, "L_RESCALE_POWER", L_power, &
                 "An integer power of 2 that is used to rescale the model's "//&
                 "intenal units of lateral distances.  Valid values range from -300 to 300.", &
                 units="nondim", default=0, debuggingParam=.true.)
  call get_param(param_file, mdl, "T_RESCALE_POWER", T_power, &
                 "An integer power of 2 that is used to rescale the model's "//&
                 "intenal units of time.  Valid values range from -300 to 300.", &
                 units="nondim", default=0, debuggingParam=.true.)
  if (abs(Z_power) > 300) call MOM_error(FATAL, "unit_scaling_init: "//&
                 "Z_RESCALE_POWER is outside of the valid range of -300 to 300.")
  if (abs(L_power) > 300) call MOM_error(FATAL, "unit_scaling_init: "//&
                 "L_RESCALE_POWER is outside of the valid range of -300 to 300.")
  if (abs(T_power) > 300) call MOM_error(FATAL, "unit_scaling_init: "//&
                 "T_RESCALE_POWER is outside of the valid range of -300 to 300.")

  Z_rescale_factor = 1.0
  if (Z_power /= 0) Z_rescale_factor = 2.0**Z_power
  US%Z_to_m = 1.0 * Z_rescale_factor
  US%m_to_Z = 1.0 / Z_rescale_factor

  L_rescale_factor = 1.0
  if (L_power /= 0) L_rescale_factor = 2.0**L_power
  US%L_to_m = 1.0 * L_rescale_factor
  US%m_to_L = 1.0 / L_rescale_factor

  T_rescale_factor = 1.0
  if (T_power /= 0) T_rescale_factor = 2.0**T_power
  US%T_to_s = 1.0 * T_rescale_factor
  US%s_to_T = 1.0 / T_rescale_factor

  ! These are useful combinations of the fundamental scale conversion factors set above.
  US%Z_to_L = US%Z_to_m * US%m_to_L
  US%L_to_Z = US%L_to_m * US%m_to_Z
  US%L_T_to_m_s = US%L_to_m * US%s_to_T
  US%m_s_to_L_T = US%m_to_L * US%T_to_s
  US%L_T2_to_m_s2 = US%L_to_m * US%s_to_T**2
  ! It does not look like US%m_s2_to_L_T2 would be used, so it does not exist.
  US%Z2_T_to_m2_s = US%Z_to_m**2 * US%s_to_T
  US%m2_s_to_Z2_T = US%m_to_Z**2 * US%T_to_s

end subroutine unit_scaling_init

!> Set the unit scaling factors for output to restart files to the unit scaling
!! factors for this run.
subroutine fix_restart_unit_scaling(US)
  type(unit_scale_type), intent(inout) :: US !< A dimensional unit scaling type

  US%m_to_Z_restart = US%m_to_Z
  US%m_to_L_restart = US%m_to_L
  US%s_to_T_restart = US%s_to_T

end subroutine fix_restart_unit_scaling

!> Deallocates a unit scaling structure.
subroutine unit_scaling_end( US )
  type(unit_scale_type), pointer :: US !< A dimensional unit scaling type

  deallocate( US )

end subroutine unit_scaling_end

end module MOM_unit_scaling
