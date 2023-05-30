! Copyright (c), The Regents of the University of California
! Terms of use are as specified in LICENSE.txt
module inputs_m
  use kind_parameters_m, only : rkind
  implicit none

  private
  public :: inputs_t

  type inputs_t
    real(rkind), allocatable :: inputs_(:)
  contains
    procedure inputs
  end type

  interface

    pure module function inputs(self) result(my_inputs)
      implicit none
      class(inputs_t), intent(in) :: self
      real(rkind), allocatable :: my_inputs(:)
    end function

  end interface

end module inputs_m