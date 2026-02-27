import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class EmailService {
  // SMTP Configuration
  static const String smtpHost = 'mail.anaghasafar.com'; // Outgoing mail server
  static const String smtpUsername = 'info@anaghasafar.com';
  static const String smtpPassword = 'Uabiotech*2309';
  static const int smtpPort = 587; // Standard SMTP port with TLS
  static const bool smtpSsl = false; // Use TLS (not SSL)
  static const String smtpDomain = 'anaghasafar.com';
  
  // Recipient email
  static const String adminEmail = 'info@uabiotech.in';
  
  // Web admin panel URL - Update this to your server's public IP or domain
  // For localhost development: http://127.0.0.1:8000/admin_panel.html
  // For production: https://your-domain.com/admin_panel.html
  
  // API base URL
  static String get apiBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (e) {
      // Fallback
    }
    return 'http://127.0.0.1:8000';
  }

  static String get adminPanelUrl {
      if (kIsWeb) return 'http://127.0.0.1:8000/admin_panel.html';
      try {
        if (Platform.isAndroid) return 'http://10.0.2.2:8000/admin_panel.html';
      } catch (e) {
        // Fallback
      }
      return 'http://127.0.0.1:8000/admin_panel.html';
  }

  /// Send hospital registration approval notification email
  static Future<bool> sendHospitalRegistrationEmail({
    required String hospitalName,
    required String hospitalEmail,
    required String hospitalMobile,
    int? hospitalId,
    String? addressLine1,
    String? addressLine2,
    String? addressLine3,
    String? city,
    String? state,
    String? pincode,
    bool? whatsappEnabled,
    String? defaultUpiId,
    String? googlePayUpiId,
    String? phonePeUpiId,
    String? paytmUpiId,
    String? bhimUpiId,
  }) async {
    // Try multiple SMTP configurations
    final smtpConfigs = [
      // Try port 587 with TLS first
      SmtpServer(
        smtpHost,
        username: smtpUsername,
        password: smtpPassword,
        port: 587,
        ssl: false,
        allowInsecure: false,
      ),
      // Try port 465 with SSL
      SmtpServer(
        smtpHost,
        username: smtpUsername,
        password: smtpPassword,
        port: 465,
        ssl: true,
        allowInsecure: false,
      ),
      // Try port 25 (fallback)
      SmtpServer(
        smtpHost,
        username: smtpUsername,
        password: smtpPassword,
        port: 25,
        ssl: false,
        allowInsecure: true,
      ),
    ];

    // Build email body (create once, use for all attempts)
    final emailBody = '''
New Hospital Registration Request

Hospital Details:
-----------------
Hospital Name: $hospitalName
Email: $hospitalEmail
Mobile: $hospitalMobile
Address Line 1: ${addressLine1 ?? 'N/A'}
Address Line 2: ${addressLine2 ?? 'N/A'}
Address Line 3: ${addressLine3 ?? 'N/A'}
City: ${city ?? 'N/A'}
State: ${state ?? 'N/A'}
Pincode: ${pincode ?? 'N/A'}

WhatsApp Integration: ${whatsappEnabled == true ? 'Enabled' : 'Disabled'}

Payment UPI IDs:
----------------
Default UPI ID: ${defaultUpiId ?? 'Not provided'}
Google Pay UPI ID: ${googlePayUpiId ?? 'Not provided'}
PhonePe UPI ID: ${phonePeUpiId ?? 'Not provided'}
Paytm UPI ID: ${paytmUpiId ?? 'Not provided'}
BHIM UPI ID: ${bhimUpiId ?? 'Not provided'}

Please review and approve this hospital registration.

---
This is an automated email from Anagha Hospital Solutions.
    ''';

    // Create message (create once, use for all attempts)
    final message = Message()
        ..from = Address(smtpUsername, 'Anagha Hospital Solutions')
        ..recipients.add(adminEmail)
        ..subject = 'New Hospital Registration Request - $hospitalName'
        ..text = emailBody
        ..html = '''
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
        .section { margin: 20px 0; padding: 15px; background-color: #f9f9f9; border-left: 4px solid #4CAF50; }
        .label { font-weight: bold; color: #555; }
        .footer { margin-top: 30px; padding: 15px; background-color: #f0f0f0; text-align: center; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h2>New Hospital Registration Request</h2>
    </div>
    <div class="content">
        <div class="section">
            <h3>Hospital Details</h3>
            <p><span class="label">Hospital Name:</span> $hospitalName</p>
            <p><span class="label">Email:</span> $hospitalEmail</p>
            <p><span class="label">Mobile:</span> $hospitalMobile</p>
            <p><span class="label">Address Line 1:</span> ${addressLine1 ?? 'N/A'}</p>
            <p><span class="label">Address Line 2:</span> ${addressLine2 ?? 'N/A'}</p>
            <p><span class="label">Address Line 3:</span> ${addressLine3 ?? 'N/A'}</p>
            <p><span class="label">City:</span> ${city ?? 'N/A'}</p>
            <p><span class="label">State:</span> ${state ?? 'N/A'}</p>
            <p><span class="label">Pincode:</span> ${pincode ?? 'N/A'}</p>
            <p><span class="label">WhatsApp Integration:</span> ${whatsappEnabled == true ? 'Enabled' : 'Disabled'}</p>
        </div>
        
        <div class="section">
            <h3>Payment UPI IDs</h3>
            <p><span class="label">Default UPI ID:</span> ${defaultUpiId ?? 'Not provided'}</p>
            <p><span class="label">Google Pay UPI ID:</span> ${googlePayUpiId ?? 'Not provided'}</p>
            <p><span class="label">PhonePe UPI ID:</span> ${phonePeUpiId ?? 'Not provided'}</p>
            <p><span class="label">Paytm UPI ID:</span> ${paytmUpiId ?? 'Not provided'}</p>
            <p><span class="label">BHIM UPI ID:</span> ${bhimUpiId ?? 'Not provided'}</p>
        </div>
        
        <div style="margin-top: 30px; padding: 20px; background-color: #e8f5e9; border: 2px solid #4CAF50; border-radius: 8px; text-align: center;">
            <h3 style="color: #2e7d32; margin-top: 0;">Action Required: Approve Hospital Registration</h3>
            <p style="margin: 15px 0; font-size: 14px; font-weight: bold;">To approve this hospital:</p>
            ${hospitalId != null ? '''
            <div style="background-color: white; padding: 20px; border-radius: 8px; margin: 15px 0; border: 2px solid #4CAF50;">
                <p style="font-size: 18px; font-weight: bold; color: #2e7d32; margin-bottom: 15px; text-align: center;">✅ How to Approve Hospital</p>
                
                <!-- Web Admin Panel Option -->
                <div style="background-color: #e3f2fd; padding: 15px; border-radius: 8px; margin-bottom: 15px; border-left: 4px solid #2196F3;">
                    <p style="font-size: 16px; font-weight: bold; color: #1976d2; margin-bottom: 10px;">🌐 Method 1: Web Admin Panel (Recommended)</p>
                    <p style="font-size: 14px; color: #555; margin-bottom: 10px;">Click the button below to open the web admin panel:</p>
                    <a href="$adminPanelUrl" 
                       style="display: inline-block; padding: 12px 25px; background-color: #2196F3; color: white; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 14px; margin: 5px 0;">
                       🌐 Open Web Admin Panel
                    </a>
                    <p style="font-size: 12px; color: #666; margin-top: 10px;">
                       Or copy this URL: <strong>$adminPanelUrl</strong>
                    </p>
                </div>
                
                <!-- Mobile App Option -->
                <div style="background-color: #f0f7ff; padding: 15px; border-radius: 8px; margin-bottom: 15px; border-left: 4px solid #4CAF50;">
                    <p style="font-size: 16px; font-weight: bold; color: #2e7d32; margin-bottom: 10px;">📱 Method 2: Mobile App Admin Panel</p>
                    <ol style="text-align: left; color: #555; font-size: 14px; line-height: 2; margin: 0; padding-left: 20px;">
                        <li>Open the <strong style="color: #2e7d32;">Anagha Hospital Solutions</strong> app on your Android phone</li>
                        <li>Click on the <strong style="color: #ff9800;">"Admin Login"</strong> button</li>
                        <li>Login with:
                            <ul style="margin-top: 5px; padding-left: 20px;">
                                <li>Username: <strong>anagha</strong></li>
                                <li>Password: <strong>Uabiotech*2309</strong></li>
                            </ul>
                        </li>
                        <li>Go to <strong>"Pending"</strong> tab</li>
                        <li>Find hospital ID: <strong>$hospitalId</strong> or Email: <strong>$hospitalEmail</strong></li>
                        <li>Click <strong style="color: #4CAF50;">"Approve Hospital"</strong></li>
                    </ol>
                </div>
            </div>
            <div style="background-color: #fff3cd; padding: 15px; border-radius: 8px; margin: 15px 0; border: 2px solid #ffc107;">
                <p style="font-size: 14px; color: #856404; margin: 0;">
                    <strong>Hospital ID:</strong> $hospitalId<br>
                    <strong>Hospital Email:</strong> $hospitalEmail<br>
                    <strong>Hospital Mobile:</strong> $hospitalMobile
                </p>
            </div>
            <div style="background-color: #fff3cd; padding: 12px; border-radius: 6px; margin-top: 15px; border-left: 4px solid #ffc107;">
                <p style="font-size: 12px; color: #856404; margin: 0;">
                    <strong>⚠️ Important:</strong> Do not use any web links. Please use the Admin Panel in the mobile app as described above. The app will automatically send a confirmation email to the hospital after approval.
                </p>
            </div>
            ''' : '''
            <p style="color: #d32f2f; font-weight: bold;">Hospital ID not available. Please approve manually through the admin panel.</p>
            <p style="margin-top: 10px; font-size: 12px;">Hospital Email: $hospitalEmail</p>
            <p style="font-size: 12px;">Hospital Mobile: $hospitalMobile</p>
            <p style="margin-top: 15px; font-size: 14px; color: #666;">
                Please open the app, go to Admin Login, and approve this hospital from the Pending tab.
            </p>
            '''}
        </div>
    </div>
    <div class="footer">
        <p>This is an automated email from Anagha Hospital Solutions</p>
        <p style="font-size: 11px; color: #999; margin-top: 5px;">If you did not request this, please ignore this email.</p>
    </div>
</body>
</html>
    ''';

    // Try each SMTP configuration
    for (final smtpServer in smtpConfigs) {
      try {
        print('Attempting to send email using port ${smtpServer.port}...');
        
        // Send email
        final sendReport = await send(message, smtpServer);
        
        // Check if email was sent successfully
        if (sendReport.toString().contains('MessageId') || 
            sendReport.toString().contains('sent')) {
          print('Email sent successfully using port ${smtpServer.port}');
          return true;
        }
      } catch (e) {
        print('Email sending error with port ${smtpServer.port}: $e');
        // Try next configuration
        continue;
      }
    }
    
    // If all configurations failed
    print('All SMTP configurations failed');
    return false;
  }

  /// Send confirmation email to hospital after approval
  static Future<bool> sendHospitalApprovalConfirmationEmail({
    required String hospitalName,
    required String hospitalEmail,
    required String hospitalMobile,
  }) async {
    // Try multiple SMTP configurations
    final smtpConfigs = [
      SmtpServer(
        smtpHost,
        username: smtpUsername,
        password: smtpPassword,
        port: 587,
        ssl: false,
        allowInsecure: false,
      ),
      SmtpServer(
        smtpHost,
        username: smtpUsername,
        password: smtpPassword,
        port: 465,
        ssl: true,
        allowInsecure: false,
      ),
      SmtpServer(
        smtpHost,
        username: smtpUsername,
        password: smtpPassword,
        port: 25,
        ssl: false,
        allowInsecure: true,
      ),
    ];

    final emailBody = '''
Congratulations! Your Hospital Registration Has Been Approved

Dear $hospitalName,

We are pleased to inform you that your hospital registration has been approved by the administrator.

Your hospital is now active in the Anagha Hospital Solutions system and can be selected by patients and other users during registration.

Hospital Details:
-----------------
Hospital Name: $hospitalName
Email: $hospitalEmail
Mobile: $hospitalMobile

Next Steps:
-----------
1. Your hospital will now appear in the hospital selection list
2. Patients and users can select your hospital during registration
3. You can start receiving appointment bookings
4. Download the app from Google Play Store or share the app link with patients

If you have any questions, please contact us at info@uabiotech.in

Thank you for choosing Anagha Hospital Solutions!

Best regards,
Anagha Hospital Solutions Team
    ''';

    final message = Message()
      ..from = Address(smtpUsername, 'Anagha Hospital Solutions')
      ..recipients.add(hospitalEmail)
      ..subject = 'Hospital Registration Approved - $hospitalName'
      ..text = emailBody
      ..html = '''
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
        .success-box { margin: 20px 0; padding: 20px; background-color: #e8f5e9; border: 2px solid #4CAF50; border-radius: 8px; text-align: center; }
        .section { margin: 20px 0; padding: 15px; background-color: #f9f9f9; border-left: 4px solid #4CAF50; }
        .label { font-weight: bold; color: #555; }
        .footer { margin-top: 30px; padding: 15px; background-color: #f0f0f0; text-align: center; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h2>🎉 Registration Approved!</h2>
    </div>
    <div class="content">
        <div class="success-box">
            <h3 style="color: #2e7d32; margin-top: 0;">Congratulations!</h3>
            <p style="font-size: 16px; margin: 10px 0;">Your hospital registration has been <strong>APPROVED</strong> by the administrator.</p>
        </div>
        
        <div class="section">
            <h3>Hospital Details</h3>
            <p><span class="label">Hospital Name:</span> $hospitalName</p>
            <p><span class="label">Email:</span> $hospitalEmail</p>
            <p><span class="label">Mobile:</span> $hospitalMobile</p>
        </div>
        
        <div class="section">
            <h3>What's Next?</h3>
            <ul style="line-height: 2;">
                <li>✅ Your hospital is now active in the system</li>
                <li>✅ Patients can select your hospital during registration</li>
                <li>✅ You can start receiving appointment bookings</li>
                <li>✅ Share the app link with patients or download from Google Play Store</li>
            </ul>
        </div>
        
        <p style="margin-top: 20px; padding: 15px; background-color: #e3f2fd; border-left: 4px solid #2196F3;">
            <strong>Need Help?</strong> Contact us at <a href="mailto:info@uabiotech.in">info@uabiotech.in</a>
        </p>
    </div>
    <div class="footer">
        <p>This is an automated email from Anagha Hospital Solutions</p>
    </div>
</body>
</html>
    ''';

    // Try each SMTP configuration
    for (final smtpServer in smtpConfigs) {
      try {
        print('Attempting to send confirmation email using port ${smtpServer.port}...');
        
        final sendReport = await send(message, smtpServer);
        
        if (sendReport.toString().contains('MessageId') || 
            sendReport.toString().contains('sent')) {
          print('Confirmation email sent successfully using port ${smtpServer.port}');
          return true;
        }
      } catch (e) {
        print('Confirmation email error with port ${smtpServer.port}: $e');
        continue;
      }
    }
    
    print('All SMTP configurations failed for confirmation email');
    return false;
  }
}
