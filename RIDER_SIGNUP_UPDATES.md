# Rider Signup Screen - Vehicle Details Update

## Summary
Updated the rider signup screen to include comprehensive vehicle details and integrated with the `VehicleModel` from the existing codebase.

## Changes Made

### 1. Updated `rider_signup_screen.dart`

#### Added New Controllers:
```dart
final _plateNumberController = TextEditingController();
final _vehicleModelController = TextEditingController();
final _vehicleColorController = TextEditingController();
```

#### Integrated VehicleModel:
- **Import**: Added `import '../../../models/vehicle_model.dart';`
- **Vehicle Types**: Now fetched from `VehicleModel.getAvailableVehicles()`
  - AUV
  - 4-Wheeler
  - 6-Wheeler
  - Wingvan
  - Trailer
  - 10-Wheeler Wingvan

#### New Form Fields Added:

1. **Vehicle Plate Number** (Required)
   - Text input with uppercase formatting
   - Icon: `Icons.confirmation_number_outlined`
   - Validation: Minimum 5 characters
   - Placeholder: "ABC 1234"

2. **Vehicle Model** (Optional)
   - Text input with word capitalization
   - Icon: `Icons.local_shipping_outlined`
   - Placeholder: "e.g., Toyota Hilux, Honda XRM"

3. **Vehicle Color** (Optional)
   - Text input with word capitalization
   - Icon: `Icons.palette_outlined`
   - Placeholder: "e.g., White, Black, Red"

#### Updated OTP Navigation:
Now passes all vehicle details to OTP verification:
```dart
RiderOTPVerificationScreen(
  phoneNumber: phoneNumber,
  isSignup: true,
  name: _nameController.text,
  email: _emailController.text.isEmpty ? null : _emailController.text,
  vehicleType: _selectedVehicleType,
  vehiclePlateNumber: _plateNumberController.text,
  vehicleModel: _vehicleModelController.text.isEmpty ? null : _vehicleModelController.text,
  vehicleColor: _vehicleColorController.text.isEmpty ? null : _vehicleColorController.text,
)
```

### 2. Updated `rider_otp_verification_screen.dart`

#### Added New Parameters:
```dart
final String? vehiclePlateNumber;
final String? vehicleModel;
final String? vehicleColor;
```

#### Updated Registration Call:
```dart
final rider = await _authService.registerRider(
  name: widget.name!,
  phoneNumber: widget.phoneNumber,
  email: widget.email,
  vehicleType: widget.vehicleType!,
  vehiclePlateNumber: widget.vehiclePlateNumber,
  vehicleModel: widget.vehicleModel,
  vehicleColor: widget.vehicleColor,
);
```

### 3. Updated `rider_auth_service.dart`

#### Enhanced `registerRider()` Method:
```dart
Future<RiderModel?> registerRider({
  required String name,
  required String phoneNumber,
  String? email,
  required String vehicleType,
  String? vehiclePlateNumber,  // NEW
  String? vehicleModel,         // NEW
  String? vehicleColor,         // NEW
})
```

Now creates `RiderModel` with complete vehicle information:
```dart
final rider = RiderModel(
  riderId: 'rider_${DateTime.now().millisecondsSinceEpoch}',
  name: name,
  phoneNumber: phoneNumber,
  email: email,
  vehicleType: vehicleType,
  vehiclePlateNumber: vehiclePlateNumber,  // NEW
  vehicleModel: vehicleModel,               // NEW
  vehicleColor: vehicleColor,               // NEW
  status: 'pending',
  isOnline: false,
  rating: 0.0,
  totalDeliveries: 0,
  totalEarnings: 0.0,
  createdAt: now,
  updatedAt: now,
);
```

## Form Layout

The signup form now follows this structure:

1. **Rider Badge** - "BECOME A RIDER"
2. **Title** - "Join Our Team"
3. **Full Name** (Required)
4. **Mobile Number** (Required)
5. **Email Address** (Optional)
6. **Vehicle Type** (Required) - Dropdown from VehicleModel
7. **Vehicle Plate Number** (Required) - NEW
8. **Vehicle Model** (Optional) - NEW
9. **Vehicle Color** (Optional) - NEW
10. **Terms and Conditions** (Required)
11. **Create Account Button**

## Validation Rules

### Required Fields:
- Full Name (min 3 characters)
- Mobile Number (min 10 digits)
- Vehicle Type (dropdown selection)
- Vehicle Plate Number (min 5 characters)
- Terms and Conditions (checkbox)

### Optional Fields:
- Email Address (validated if provided)
- Vehicle Model
- Vehicle Color

## Vehicle Types Available

From `VehicleModel.getAvailableVehicles()`:

| Type | Base Fare | Per KM Rate | Capacity |
|------|-----------|-------------|----------|
| AUV | ₱100 | ₱15 | Up to 50 kg |
| 4-Wheeler | ₱150 | ₱20 | Up to 200 kg |
| 6-Wheeler | ₱300 | ₱35 | Up to 1,000 kg |
| Wingvan | ₱500 | ₱50 | Up to 2,000 kg |
| Trailer | ₱800 | ₱80 | Up to 5,000 kg |
| 10-Wheeler Wingvan | ₱12,000 | N/A | Up to 8,000 kg |

## Benefits

1. **Complete Vehicle Information**: Captures all necessary vehicle details during registration
2. **Consistent Data**: Uses the same vehicle types as the booking system
3. **Better Verification**: Plate number helps with vehicle verification
4. **Optional Details**: Model and color help customers identify the right vehicle
5. **Scalable**: Easy to add more vehicle types through VehicleModel

## Next Steps

### Recommended Enhancements:

1. **Vehicle Photo Upload**:
   - Add image picker for vehicle photos
   - Front, side, and rear views
   - Plate number photo

2. **Document Upload**:
   - Driver's license
   - Vehicle registration (OR/CR)
   - Insurance documents

3. **Vehicle Verification**:
   - Admin approval workflow
   - Document verification status
   - Rejection reasons and resubmission

4. **Multiple Vehicles**:
   - Allow riders to register multiple vehicles
   - Switch between vehicles
   - Different rates per vehicle type

5. **Real-time Validation**:
   - Check plate number uniqueness
   - Verify against LTO database (if available)
   - Validate license number

## Testing

### Test Cases:

1. **Valid Registration**:
   - Fill all required fields
   - Select vehicle type from dropdown
   - Enter valid plate number
   - Verify OTP and complete registration

2. **Validation Tests**:
   - Try submitting without plate number
   - Enter plate number less than 5 characters
   - Leave vehicle type unselected

3. **Optional Fields**:
   - Complete registration without model/color
   - Complete registration with model/color
   - Verify data is saved correctly

4. **Vehicle Type Selection**:
   - Test all 6 vehicle types
   - Verify correct type is saved
   - Check dropdown displays all types

---

**Updated**: November 2024  
**Status**: ✅ Complete and tested
