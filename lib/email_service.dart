import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static final String _username = 'soorajsahai8@gmail.com';
  static final String _password = 'odxj ljii efsy vjyt';
  
  static final SmtpServer _smtpServer = gmail(_username, _password);
  
  static String generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }
  
  static Future<bool> sendOTPEmail(String recipientEmail, String otp) async {
    try {
      final message = Message()
        ..from = Address(_username, 'SpotIt AI')
        ..recipients.add(recipientEmail)
        ..subject = 'SpotIt AI - Email Verification OTP'
        ..html = '''
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background: linear-gradient(135deg, #4F46E5, #06B6D4); padding: 30px; border-radius: 15px; text-align: center; margin-bottom: 30px;">
              <h1 style="color: white; margin: 0; font-size: 32px;">SpotIt AI</h1>
              <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px;">Email Verification</p>
            </div>
            
            <div style="background-color: #f8f9fa; padding: 30px; border-radius: 15px; text-align: center; margin-bottom: 30px;">
              <h2 style="color: #2d3748; margin-bottom: 15px;">Your Verification Code</h2>
              <div style="background: white; border: 2px dashed #4F46E5; border-radius: 10px; padding: 20px; margin: 20px 0;">
                <span style="font-size: 36px; font-weight: bold; color: #4F46E5; letter-spacing: 8px;">$otp</span>
              </div>
              <p style="color: #718096; margin: 20px 0 0 0;">This code will expire in 10 minutes</p>
            </div>
            
            <div style="text-align: center; color: #718096; font-size: 14px;">
              <p style="margin: 0;">If you didn't request this verification, please ignore this email.</p>
              <p style="margin: 10px 0 0 0;">This is an automated message from SpotIt AI.</p>
            </div>
          </div>
        ''';

      final sendReport = await send(message, _smtpServer);
      print('Message sent: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }
}
