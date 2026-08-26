class Narrator::OutcomeSchema < RubyLLM::Schema
  string :resolution, description: "Zar sonucunu hikâyeye işleyen 1-2 kısa cümle"
  object :effects do
    integer :hp, description: "Cana etkisi; derecesine ve tehlikenin türüne göre kurallardaki aralıklardan, düz başarıda 0"
    array :items_gained, description: "Kurgunun gösterdiği yerden kazanılan eşyalar (sandık, ganimet, ödül); çoğu turda boş kalır" do
      object do
        string :name, description: "Eşyanın Türkçe adı"
        string :kind, enum: %w[instant passive quest],
          description: "instant: kullanılınca etki eder ve tükenir; passive: taşındığı sürece hikâyede iş görür; quest: görev eşyası"
        string :description, description: "Eşyanın ne işe yaradığını söyleyen 2-4 kelime; instant için boş bırak"
        integer :hp, description: "instant eşya kullanılınca cana etkisi; diğer türlerde 0"
        integer :uses, description: "instant eşyanın kaç kez kullanılabileceği; diğer türlerde 0"
      end
    end
    array :items_lost, of: :string, description: "Bu sonuçla kaybedilen eşyaların adları; çoğu turda boş kalır"
    array :statuses_gained, description: "Karaktere yapışan statüler; pozitif yalnız kritik/parlak başarıda, negatif ağır sonuçlarda — çoğu turda boş kalır" do
      object do
        string :name, description: "Anlatıdaki somut izi söyleyen Türkçe ad, örn. Kanayan Omuz, Sırılsıklam; ruh hâli sıfatı olmaz"
        integer :modifier, description: "Sonraki zarlara katkısı, -2..+2"
        integer :turns, description: "Kaç tur süreceği; bir koşula bağlıysa 0"
        string :expires_when, description: "Statüyü bitirecek koşulun etiketi, örn. 'kuruyana dek'; tur sayılıysa boş bırak"
      end
    end
    array :statuses_lost, of: :string, description: "Bu sonuçla biten statü etkilerinin adları"
  end
end
