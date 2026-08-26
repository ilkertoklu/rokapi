class Narrator::BibleSchema < RubyLLM::Schema
  string :title, description: "Maceranın adı, 2-4 kelime; hazır görevde görevin adı"
  string :premise, description: "Dünya ve görev, 2 cümle: neresi, ne tehlikede, oyuncu neden buradadır"
  string :personal_stake, description: "Oyuncu karakterini bu göreve bağlayan kişisel neden; ırkından, sınıfından ve arka planından türetilir, 1-2 cümle"
  object :antagonist, description: "Asıl karşıt güç: yüzü olan biri ya da bir şey" do
    string :name, description: "Adı"
    string :want, description: "Ne istiyor ve neden haklı olduğuna inanıyor"
    string :method, description: "Nasıl çalışıyor, kimleri kullanıyor"
    string :first_sign, description: "İlk sahnelerde hissedilen ama adı konmayan izi"
  end
  object :ally, description: "Oyuncunun yanında duran, kendi derdi olan biri" do
    string :name, description: "Adı"
    string :want, description: "Ne istiyor"
    string :secret, description: "Sakladığı ve hikâyede açığa çıkacak şey"
  end
  string :twist, description: "Orta noktada tersine dönen bilinen gerçek, 1-2 cümle"
  array :beats, of: :string, description: "Sahne sahne vuruşlar, istenen sayıda: her satır o sahnede ne olduğunu ve neyin değiştiğini söyler; son satır final"
  string :finale_question, description: "Finalin cevapladığı tek soru"
  string :victory, description: "Zaferin koşulu ve kapanış görüntüsü"
  string :defeat, description: "Yenilginin koşulu ve kapanış görüntüsü"
end
