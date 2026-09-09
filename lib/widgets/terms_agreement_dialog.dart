import 'package:flutter/material.dart';

const _font = 'Poppins';
const _bg = Color(0xFF1E1233);
const _pink = Color(0xFFFE4EF0);
const _white70 = Colors.white70;

void showTermsAgreementDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Terms & Agreement',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _TermsAgreementContent();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: child,
        ),
      );
    },
  );
}

class _TermsAgreementContent extends StatelessWidget {
  const _TermsAgreementContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                Flexible(child: _buildBody()),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: _pink, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Terms & Agreement',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white54,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WeDo Terms & Agreement',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Effective Date: September 9, 2026',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'By creating an account or using WeDo, you agree to these Terms.',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 13,
              color: _white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _buildSection(
            title: '1. Use of WeDo',
            body:
                'WeDo is a social communication and decision-making app that provides messaging, calls, polls, events, games, movie recommendations, and nearby-place features.\n\n'
                'You must be at least 13 years old to use WeDo, unless a higher age is required by law.',
          ),
          _buildSection(
            title: '2. Your Account',
            body:
                'You are responsible for keeping your account and password secure. Do not share your account or use another person\'s account without permission.',
          ),
          _buildSection(
            title: '3. User Conduct',
            body:
                'You agree not to:\n\n'
                '\u2022 Harass, threaten, bully, or impersonate others.\n'
                '\u2022 Send spam or harmful content.\n'
                '\u2022 Share illegal, abusive, hateful, or sexually explicit content.\n'
                '\u2022 Attempt to hack, disrupt, or misuse WeDo.\n'
                '\u2022 Collect other users\' personal information without permission.',
          ),
          _buildSection(
            title: '4. Your Content',
            body:
                'You are responsible for the messages, images, voice messages, polls, events, and other content you share.\n\n'
                'You retain ownership of your content, but allow WeDo to store and display it as necessary to provide the service.',
          ),
          _buildSection(
            title: '5. Location & Third-Party Services',
            body:
                'Some features require location, camera, or microphone permissions. You can disable these permissions through your device settings.\n\n'
                'WeDo uses third-party services such as Firebase, Vercel, Brevo, TMDB, OpenStreetMap, and Metered. Their services are subject to their own terms and policies.',
          ),
          _buildSection(
            title: '6. Privacy',
            body:
                'Your use of WeDo is also governed by our Privacy Policy. WeDo does not sell personal or sensitive user data.',
          ),
          _buildSection(
            title: '7. Account Termination',
            body:
                'You may delete your account through the Account section of the app. We may suspend or terminate accounts that violate these Terms or create security or legal risks.',
          ),
          _buildSection(
            title: '8. Disclaimer',
            body:
                'WeDo is provided "as is" and "as available." We do not guarantee that the app will always be available, error-free, secure, or accurate.\n\n'
                'Game results, recommendations, and third-party place information may not always be accurate or reliable.',
          ),
          _buildSection(
            title: '9. Changes',
            body:
                'We may update these Terms when necessary. Continued use of WeDo after changes means you accept the updated Terms.',
          ),
          _buildSection(
            title: '10. Governing Law',
            body:
                'These Terms are governed by the laws of the Republic of the Philippines.',
          ),
          _buildSection(
            title: '11. Contact',
            body:
                'WeDo Development Team\n'
                'Email: wedo.privacy@gmail.com\n'
                'Address: Philippines',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _pink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _pink.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agreement',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'By tapping "I Agree", you confirm that you have read, understood, and agree to these Terms & Agreement and the WeDo Privacy Policy.\n\n'
                  'If you do not agree, please do not use WeDo.',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 12,
                    color: _white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _pink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 12,
              color: _white70,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF800DD8), _pink],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Close',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _font,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
